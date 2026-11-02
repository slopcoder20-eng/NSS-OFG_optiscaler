static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1184[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1193[5] = { 2, 4, 7, 11, 16 };
static const float3 _3764[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4051 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4051.x >= cbFI_DisplaySize.x, _4051.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4051] = float4(r_present_backbuffer.Load(int3(_4051, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4512 = (float2(_4051) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4514 = float2(cbFI_MvDepthLaneSize);
        int2 _4523 = int2(floor(_4512 * _4514));
        int2 _4528 = int2(floor(_4512 * float2(cbFI_FlowLaneSize)));
        float4 _6692 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4512 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6698 = r_warped_filled_flow_tm1.Load(int3(_4528, 0)).xy;
        float2 _6704 = r_warped_filled_motion_tp1.Load(int3(_4523, 0)).xy;
        bool _6726 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _14022;
        if (_6726)
        {
            float _6739 = ((2.0f * _4512.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _14022 = float2(atan(_6739) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4512.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6739 * _6739))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _14022 = _4512;
        }
        bool _4549 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _14043;
        bool _14185;
        int2 _14266;
        float3 _16433;
        if (_4549)
        {
            float _14024;
            float _14026;
            _14026 = 2.0f;
            _14024 = -1.0f;
            uint _4133[9];
            float _17001;
            float _17004;
            for (int _14023 = 0; _14023 < 9; _14026 = _17004, _14024 = _17001, _14023++)
            {
                _4133[_14023] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4523 + int2((_14023 % 3) - 1, (_14023 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4133[_14023] != 0u)
                {
                    float _16996;
                    if (_4133[_14023] == 0u)
                    {
                        _16996 = -1.0f;
                    }
                    else
                    {
                        _16996 = float((_4133[_14023] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _17004 = min(_14026, _16996);
                    _17001 = max(_14024, _16996);
                }
                else
                {
                    _17004 = _14026;
                    _17001 = _14024;
                }
            }
            float _4595 = float(_14024 >= 0.0f);
            float3 _13725 = 0.0f.xxx;
            _13725.y = _4595;
            float2 _14044;
            bool _14186;
            int2 _14267;
            float3 _16434;
            if ((_14024 - _14026) > 0.0199999995529651641845703125f)
            {
                float _14032;
                int2 _14033;
                float2 _14034;
                int2 _14036;
                float2 _14042;
                _14042 = _6704;
                _14036 = _4523;
                _14034 = _6704;
                _14033 = _4523;
                _14032 = -1.0f;
                float _17009;
                int2 _17013;
                float2 _17024;
                int2 _17035;
                float2 _17068;
                float _17115;
                int _14031 = 0;
                float _16977 = 1000000000.0f;
                for (; _14031 < 9; _16977 = _17115, _14042 = _17068, _14036 = _17035, _14034 = _17024, _14033 = _17013, _14032 = _17009, _14031++)
                {
                    if (_4133[_14031] == 0u)
                    {
                        _17115 = _16977;
                        _17068 = _14042;
                        _17035 = _14036;
                        _17024 = _14034;
                        _17013 = _14033;
                        _17009 = _14032;
                        continue;
                    }
                    int2 _4630 = clamp(_4523 + int2((_14031 % 3) - 1, (_14031 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6814 = _4133[_14031] & 2147483647u;
                    uint _6846 = uint(max((int((_6814 >> 16u) & 15u) - 6), 0));
                    float2 _4636 = (float2(float((1 - (2 * int((_6814 >> 15u) & 1u))) * int(((_6814 >> uint(7)) & 127u) << _6846)), float((1 - (2 * int((_6814 >> 14u) & 1u))) * int((_6814 & 127u) << _6846))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _16963;
                    if (_4133[_14031] == 0u)
                    {
                        _16963 = -1.0f;
                    }
                    else
                    {
                        _16963 = float((_4133[_14031] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4641 = _16963 - 0.100000001490116119384765625f;
                    float2 _16964;
                    if (_6726)
                    {
                        float2 _6923 = clamp((((_14022 + (_4636 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6926 = tan(_6923.x);
                        _16964 = (float2(_6926 / cbFI_DeviceToViewDepth.z, (tan(_6923.y) * sqrt(1.0f + (_6926 * _6926))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _16964 = _14022 + (_4636 * cbFI_Timestep);
                    }
                    float _4648 = cbFI_Timestep - 1.0f;
                    float2 _16965;
                    if (_6726)
                    {
                        float2 _6994 = clamp((((_14022 + (_4636 * _4648)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6997 = tan(_6994.x);
                        _16965 = (float2(_6997 / cbFI_DeviceToViewDepth.z, (tan(_6994.y) * sqrt(1.0f + (_6997 * _6997))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _16965 = _14022 + (_4636 * _4648);
                    }
                    bool _7030 = all(bool2(_16964.x > 0.0f.xx.x, _16964.y > 0.0f.xx.y));
                    bool _7036;
                    if (_7030)
                    {
                        _7036 = all(bool2(_16964.x < 1.0f.xx.x, _16964.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7036 = _7030;
                    }
                    float _16968;
                    if (_7036)
                    {
                        uint _7043_dummy_parameter;
                        _16968 = max((_4641 - (log(((r_depth_tm1.Load(int3(int2(floor(_16964 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7043_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _16968 = 0.0f;
                    }
                    bool _7073 = all(bool2(_16965.x > 0.0f.xx.x, _16965.y > 0.0f.xx.y));
                    bool _7079;
                    if (_7073)
                    {
                        _7079 = all(bool2(_16965.x < 1.0f.xx.x, _16965.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7079 = _7073;
                    }
                    float _16969;
                    if (_7079)
                    {
                        uint _7086_dummy_parameter;
                        _16969 = _16968 + max((_4641 - (log(((r_depth_tp1.Load(int3(int2(floor(_16965 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7086_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _16969 = _16968;
                    }
                    float _17010;
                    int2 _17014;
                    float2 _17025;
                    int2 _17036;
                    float2 _17069;
                    float _17116;
                    if (_16969 == 0.0f)
                    {
                        bool _4683 = _4641 > _14032;
                        bool2 _17124 = _4683.xx;
                        _17116 = _16977;
                        _17069 = float2(_17124.x ? _4636.x : _14042.x, _17124.y ? _4636.y : _14042.y);
                        _17036 = int2(_17124.x ? _4630.x : _14036.x, _17124.y ? _4630.y : _14036.y);
                        _17025 = _14034;
                        _17014 = _14033;
                        _17010 = _4683 ? _4641 : _14032;
                    }
                    else
                    {
                        bool _4692 = _16969 < _16977;
                        bool2 _17120 = _4692.xx;
                        _17116 = _4692 ? _16969 : _16977;
                        _17069 = _14042;
                        _17036 = _14036;
                        _17025 = float2(_17120.x ? _4636.x : _14034.x, _17120.y ? _4636.y : _14034.y);
                        _17014 = int2(_17120.x ? _4630.x : _14033.x, _17120.y ? _4630.y : _14033.y);
                        _17010 = _14032;
                    }
                    _17115 = _17116;
                    _17068 = _17069;
                    _17035 = _17036;
                    _17024 = _17025;
                    _17013 = _17014;
                    _17009 = _17010;
                }
                bool _4704 = _14032 < 0.0f;
                bool2 _17130 = _4704.xx;
                int2 _17133 = int2(_17130.x ? _14033.x : _14036.x, _17130.y ? _14033.y : _14036.y);
                _16434 = float3(1.0f, _4595, float(any(bool2(_17133.x != _4523.x, _17133.y != _4523.y))));
                _14267 = _17133;
                _14186 = _4704 ? false : true;
                _14044 = float2(_17130.x ? _14034.x : _14042.x, _17130.y ? _14034.y : _14042.y);
            }
            else
            {
                _16434 = _13725;
                _14267 = _4523;
                _14186 = false;
                _14044 = _6704;
            }
            _16433 = _16434;
            _14266 = _14267;
            _14185 = _14186;
            _14043 = _14044;
        }
        else
        {
            _16433 = 0.0f.xxx;
            _14266 = _4523;
            _14185 = false;
            _14043 = _6704;
        }
        float2 _14045;
        if (_6726)
        {
            float2 _7151 = clamp((((_14022 + (_14043 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7154 = tan(_7151.x);
            _14045 = (float2(_7154 / cbFI_DeviceToViewDepth.z, (tan(_7151.y) * sqrt(1.0f + (_7154 * _7154))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14045 = _14022 + (_14043 * cbFI_Timestep);
        }
        float _4727 = cbFI_Timestep - 1.0f;
        float2 _14047;
        if (_6726)
        {
            float2 _7222 = clamp((((_14022 + (_14043 * _4727)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7225 = tan(_7222.x);
            _14047 = (float2(_7225 / cbFI_DeviceToViewDepth.z, (tan(_7222.y) * sqrt(1.0f + (_7225 * _7225))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14047 = _14022 + (_14043 * _4727);
        }
        float _4732 = -cbFI_Timestep;
        float2 _14048;
        if (_6726)
        {
            float2 _7293 = clamp((((_14022 + (_6698 * _4732)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7296 = tan(_7293.x);
            _14048 = (float2(_7296 / cbFI_DeviceToViewDepth.z, (tan(_7293.y) * sqrt(1.0f + (_7296 * _7296))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14048 = _14022 + (_6698 * _4732);
        }
        float _4737 = 1.0f - cbFI_Timestep;
        float2 _14049;
        if (_6726)
        {
            float2 _7364 = clamp((((_14022 + (_6698 * _4737)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7367 = tan(_7364.x);
            _14049 = (float2(_7367 / cbFI_DeviceToViewDepth.z, (tan(_7364.y) * sqrt(1.0f + (_7367 * _7367))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14049 = _14022 + (_6698 * _4737);
        }
        float4 _7402 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14045, 0.0f);
        float3 _7403 = _7402.xyz;
        float4 _7410 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14047, 0.0f);
        float3 _7411 = _7410.xyz;
        float4 _7418 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14048, 0.0f);
        float3 _7419 = _7418.xyz;
        float4 _7426 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14049, 0.0f);
        float3 _7427 = _7426.xyz;
        float4 _7441 = exp(_6692 - max(max(max(_6692.x, _6692.y), _6692.z), _6692.w).xxxx);
        float4 _7448 = _7441 / (dot(_7441, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4753 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _14256;
        float _15564;
        if (_4753)
        {
            float2 _4759 = 0.5f.xx / _4514;
            float _4762 = _4759.x;
            float _4763 = -_4762;
            float _4765 = _4759.y;
            float _4766 = -_4765;
            float2 _4768 = _4512 + float2(_4763, _4766);
            float2 _4770 = float2(cbFI_DisplaySize);
            bool _14066;
            do
            {
                bool _7528 = all(bool2(_4768.x > 0.0f.xx.x, _4768.y > 0.0f.xx.y));
                bool _7534;
                if (_7528)
                {
                    _7534 = all(bool2(_4768.x < 1.0f.xx.x, _4768.y < 1.0f.xx.y));
                }
                else
                {
                    _7534 = _7528;
                }
                if (!_7534)
                {
                    _14066 = false;
                    break;
                }
                uint _7541_dummy_parameter;
                float4x4 _14064;
                do
                {
                    float4x4 _7555;
                    bool _14063;
                    do
                    {
                        _7555 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14063 = false;
                            break;
                        }
                        uint _7589 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7589 + 32u) * 4 + 0) != 1u)
                        {
                            _14063 = false;
                            break;
                        }
                        uint _14060;
                        _14060 = 0u;
                        for (; _14060 < 4u; _14060++)
                        {
                            for (uint _14061 = 0u; _14061 < 4u; )
                            {
                                _7555[_14060][_14061] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7589 + (_14060 * 4u)) + _14061) * 4 + 0));
                                _14061++;
                                continue;
                            }
                        }
                        _14063 = true;
                        break;
                    } while(false);
                    if (_14063)
                    {
                        _14064 = _7555;
                        break;
                    }
                    _14064 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14065;
                do
                {
                    float _7666 = _4768.x;
                    float _7669 = 1.0f - _4768.y;
                    float4 _7680 = mul(float4((float2(_7666, _7669) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4768 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7541_dummy_parameter))))), 0)).x, 1.0f), _14064);
                    float _7682 = _7680.w;
                    if (!(_7682 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14065 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7695 = ((_7680.xy / _7682.xx) + 1.0f.xx) * 0.5f;
                    _14065 = float2(_7695.x - _7666, _7669 - _7695.y);
                    break;
                } while(false);
                float2 _7492 = abs(_14065);
                if (any(bool2(_7492.x > 100000.0f.xx.x, _7492.y > 100000.0f.xx.y)))
                {
                    _14066 = false;
                    break;
                }
                float _7500 = length(_14065 * _4770);
                uint _7715_dummy_parameter;
                bool _7514 = _7500 > ((8.0f * _4770.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7521;
                if (_7514)
                {
                    _7521 = length((r_motion_tp1.Load(int3(int2(floor(_4768 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7715_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4770) < (0.20000000298023223876953125f * _7500);
                }
                else
                {
                    _7521 = _7514;
                }
                _14066 = _7521;
                break;
            } while(false);
            float2 _4780 = _4512 + float2(_4762, _4766);
            bool _14073;
            do
            {
                bool _7801 = all(bool2(_4780.x > 0.0f.xx.x, _4780.y > 0.0f.xx.y));
                bool _7807;
                if (_7801)
                {
                    _7807 = all(bool2(_4780.x < 1.0f.xx.x, _4780.y < 1.0f.xx.y));
                }
                else
                {
                    _7807 = _7801;
                }
                if (!_7807)
                {
                    _14073 = false;
                    break;
                }
                uint _7814_dummy_parameter;
                float4x4 _14071;
                do
                {
                    float4x4 _7828;
                    bool _14070;
                    do
                    {
                        _7828 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14070 = false;
                            break;
                        }
                        uint _7862 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7862 + 32u) * 4 + 0) != 1u)
                        {
                            _14070 = false;
                            break;
                        }
                        uint _14067;
                        _14067 = 0u;
                        for (; _14067 < 4u; _14067++)
                        {
                            for (uint _14068 = 0u; _14068 < 4u; )
                            {
                                _7828[_14067][_14068] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7862 + (_14067 * 4u)) + _14068) * 4 + 0));
                                _14068++;
                                continue;
                            }
                        }
                        _14070 = true;
                        break;
                    } while(false);
                    if (_14070)
                    {
                        _14071 = _7828;
                        break;
                    }
                    _14071 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14072;
                do
                {
                    float _7939 = _4780.x;
                    float _7942 = 1.0f - _4780.y;
                    float4 _7953 = mul(float4((float2(_7939, _7942) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4780 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7814_dummy_parameter))))), 0)).x, 1.0f), _14071);
                    float _7955 = _7953.w;
                    if (!(_7955 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14072 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7968 = ((_7953.xy / _7955.xx) + 1.0f.xx) * 0.5f;
                    _14072 = float2(_7968.x - _7939, _7942 - _7968.y);
                    break;
                } while(false);
                float2 _7765 = abs(_14072);
                if (any(bool2(_7765.x > 100000.0f.xx.x, _7765.y > 100000.0f.xx.y)))
                {
                    _14073 = false;
                    break;
                }
                float _7773 = length(_14072 * _4770);
                uint _7988_dummy_parameter;
                bool _7787 = _7773 > ((8.0f * _4770.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7794;
                if (_7787)
                {
                    _7794 = length((r_motion_tp1.Load(int3(int2(floor(_4780 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7988_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4770) < (0.20000000298023223876953125f * _7773);
                }
                else
                {
                    _7794 = _7787;
                }
                _14073 = _7794;
                break;
            } while(false);
            float2 _4793 = _4512 + float2(_4763, _4765);
            bool _14080;
            do
            {
                bool _8074 = all(bool2(_4793.x > 0.0f.xx.x, _4793.y > 0.0f.xx.y));
                bool _8080;
                if (_8074)
                {
                    _8080 = all(bool2(_4793.x < 1.0f.xx.x, _4793.y < 1.0f.xx.y));
                }
                else
                {
                    _8080 = _8074;
                }
                if (!_8080)
                {
                    _14080 = false;
                    break;
                }
                uint _8087_dummy_parameter;
                float4x4 _14078;
                do
                {
                    float4x4 _8101;
                    bool _14077;
                    do
                    {
                        _8101 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14077 = false;
                            break;
                        }
                        uint _8135 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8135 + 32u) * 4 + 0) != 1u)
                        {
                            _14077 = false;
                            break;
                        }
                        uint _14074;
                        _14074 = 0u;
                        for (; _14074 < 4u; _14074++)
                        {
                            for (uint _14075 = 0u; _14075 < 4u; )
                            {
                                _8101[_14074][_14075] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8135 + (_14074 * 4u)) + _14075) * 4 + 0));
                                _14075++;
                                continue;
                            }
                        }
                        _14077 = true;
                        break;
                    } while(false);
                    if (_14077)
                    {
                        _14078 = _8101;
                        break;
                    }
                    _14078 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14079;
                do
                {
                    float _8212 = _4793.x;
                    float _8215 = 1.0f - _4793.y;
                    float4 _8226 = mul(float4((float2(_8212, _8215) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4793 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8087_dummy_parameter))))), 0)).x, 1.0f), _14078);
                    float _8228 = _8226.w;
                    if (!(_8228 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14079 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8241 = ((_8226.xy / _8228.xx) + 1.0f.xx) * 0.5f;
                    _14079 = float2(_8241.x - _8212, _8215 - _8241.y);
                    break;
                } while(false);
                float2 _8038 = abs(_14079);
                if (any(bool2(_8038.x > 100000.0f.xx.x, _8038.y > 100000.0f.xx.y)))
                {
                    _14080 = false;
                    break;
                }
                float _8046 = length(_14079 * _4770);
                uint _8261_dummy_parameter;
                bool _8060 = _8046 > ((8.0f * _4770.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8067;
                if (_8060)
                {
                    _8067 = length((r_motion_tp1.Load(int3(int2(floor(_4793 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8261_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4770) < (0.20000000298023223876953125f * _8046);
                }
                else
                {
                    _8067 = _8060;
                }
                _14080 = _8067;
                break;
            } while(false);
            float2 _4805 = _4512 + _4759;
            bool _14087;
            do
            {
                bool _8347 = all(bool2(_4805.x > 0.0f.xx.x, _4805.y > 0.0f.xx.y));
                bool _8353;
                if (_8347)
                {
                    _8353 = all(bool2(_4805.x < 1.0f.xx.x, _4805.y < 1.0f.xx.y));
                }
                else
                {
                    _8353 = _8347;
                }
                if (!_8353)
                {
                    _14087 = false;
                    break;
                }
                uint _8360_dummy_parameter;
                float4x4 _14085;
                do
                {
                    float4x4 _8374;
                    bool _14084;
                    do
                    {
                        _8374 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14084 = false;
                            break;
                        }
                        uint _8408 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8408 + 32u) * 4 + 0) != 1u)
                        {
                            _14084 = false;
                            break;
                        }
                        uint _14081;
                        _14081 = 0u;
                        for (; _14081 < 4u; _14081++)
                        {
                            for (uint _14082 = 0u; _14082 < 4u; )
                            {
                                _8374[_14081][_14082] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8408 + (_14081 * 4u)) + _14082) * 4 + 0));
                                _14082++;
                                continue;
                            }
                        }
                        _14084 = true;
                        break;
                    } while(false);
                    if (_14084)
                    {
                        _14085 = _8374;
                        break;
                    }
                    _14085 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14086;
                do
                {
                    float _8485 = _4805.x;
                    float _8488 = 1.0f - _4805.y;
                    float4 _8499 = mul(float4((float2(_8485, _8488) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4805 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8360_dummy_parameter))))), 0)).x, 1.0f), _14085);
                    float _8501 = _8499.w;
                    if (!(_8501 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14086 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8514 = ((_8499.xy / _8501.xx) + 1.0f.xx) * 0.5f;
                    _14086 = float2(_8514.x - _8485, _8488 - _8514.y);
                    break;
                } while(false);
                float2 _8311 = abs(_14086);
                if (any(bool2(_8311.x > 100000.0f.xx.x, _8311.y > 100000.0f.xx.y)))
                {
                    _14087 = false;
                    break;
                }
                float _8319 = length(_14086 * _4770);
                uint _8534_dummy_parameter;
                bool _8333 = _8319 > ((8.0f * _4770.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8340;
                if (_8333)
                {
                    _8340 = length((r_motion_tp1.Load(int3(int2(floor(_4805 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8534_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4770) < (0.20000000298023223876953125f * _8319);
                }
                else
                {
                    _8340 = _8333;
                }
                _14087 = _8340;
                break;
            } while(false);
            float _4811 = 0.25f * (((float(_14066) + float(_14073)) + float(_14080)) + float(_14087));
            float4 _14257;
            if (_4811 < 1.0f)
            {
                bool _14094;
                do
                {
                    bool _8620 = all(bool2(_14045.x > 0.0f.xx.x, _14045.y > 0.0f.xx.y));
                    bool _8626;
                    if (_8620)
                    {
                        _8626 = all(bool2(_14045.x < 1.0f.xx.x, _14045.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8626 = _8620;
                    }
                    if (!_8626)
                    {
                        _14094 = false;
                        break;
                    }
                    uint _8633_dummy_parameter;
                    float4x4 _14092;
                    do
                    {
                        float4x4 _8647;
                        bool _14091;
                        do
                        {
                            _8647 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14091 = false;
                                break;
                            }
                            uint _8681 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_8681 + 32u) * 4 + 0) != 1u)
                            {
                                _14091 = false;
                                break;
                            }
                            uint _14088;
                            _14088 = 0u;
                            for (; _14088 < 4u; _14088++)
                            {
                                for (uint _14089 = 0u; _14089 < 4u; )
                                {
                                    _8647[_14088][_14089] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8681 + (_14088 * 4u)) + _14089) * 4 + 0));
                                    _14089++;
                                    continue;
                                }
                            }
                            _14091 = true;
                            break;
                        } while(false);
                        if (_14091)
                        {
                            _14092 = _8647;
                            break;
                        }
                        _14092 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14093;
                    do
                    {
                        float _8761 = 1.0f - _14045.y;
                        float4 _8772 = mul(float4((float2(_14045.x, _8761) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14045 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8633_dummy_parameter))))), 0)).x, 1.0f), _14092);
                        float _8774 = _8772.w;
                        if (!(_8774 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14093 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8787 = ((_8772.xy / _8774.xx) + 1.0f.xx) * 0.5f;
                        _14093 = float2(_8787.x - _14045.x, _8761 - _8787.y);
                        break;
                    } while(false);
                    float2 _8584 = abs(_14093);
                    if (any(bool2(_8584.x > 100000.0f.xx.x, _8584.y > 100000.0f.xx.y)))
                    {
                        _14094 = false;
                        break;
                    }
                    float _8592 = length(_14093 * _4770);
                    uint _8807_dummy_parameter;
                    bool _8606 = _8592 > ((8.0f * _4770.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8613;
                    if (_8606)
                    {
                        _8613 = length((r_motion_tp1.Load(int3(int2(floor(_14045 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8807_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4770) < (0.20000000298023223876953125f * _8592);
                    }
                    else
                    {
                        _8613 = _8606;
                    }
                    _14094 = _8613;
                    break;
                } while(false);
                bool _14101;
                do
                {
                    bool _8893 = all(bool2(_14047.x > 0.0f.xx.x, _14047.y > 0.0f.xx.y));
                    bool _8899;
                    if (_8893)
                    {
                        _8899 = all(bool2(_14047.x < 1.0f.xx.x, _14047.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8899 = _8893;
                    }
                    if (!_8899)
                    {
                        _14101 = false;
                        break;
                    }
                    uint _8906_dummy_parameter;
                    float4x4 _14099;
                    do
                    {
                        float4x4 _8920;
                        bool _14098;
                        do
                        {
                            _8920 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14098 = false;
                                break;
                            }
                            uint _8954 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_8954 + 32u) * 4 + 0) != 1u)
                            {
                                _14098 = false;
                                break;
                            }
                            uint _14095;
                            _14095 = 0u;
                            for (; _14095 < 4u; _14095++)
                            {
                                for (uint _14096 = 0u; _14096 < 4u; )
                                {
                                    _8920[_14095][_14096] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8954 + (_14095 * 4u)) + _14096) * 4 + 0));
                                    _14096++;
                                    continue;
                                }
                            }
                            _14098 = true;
                            break;
                        } while(false);
                        if (_14098)
                        {
                            _14099 = _8920;
                            break;
                        }
                        _14099 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14100;
                    do
                    {
                        float _9034 = 1.0f - _14047.y;
                        float4 _9045 = mul(float4((float2(_14047.x, _9034) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8906_dummy_parameter))))), 0)).x, 1.0f), _14099);
                        float _9047 = _9045.w;
                        if (!(_9047 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14100 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9060 = ((_9045.xy / _9047.xx) + 1.0f.xx) * 0.5f;
                        _14100 = float2(_9060.x - _14047.x, _9034 - _9060.y);
                        break;
                    } while(false);
                    float2 _8857 = abs(_14100);
                    if (any(bool2(_8857.x > 100000.0f.xx.x, _8857.y > 100000.0f.xx.y)))
                    {
                        _14101 = false;
                        break;
                    }
                    float _8865 = length(_14100 * _4770);
                    uint _9080_dummy_parameter;
                    bool _8879 = _8865 > ((8.0f * _4770.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8886;
                    if (_8879)
                    {
                        _8886 = length((r_motion_tp1.Load(int3(int2(floor(_14047 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9080_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4770) < (0.20000000298023223876953125f * _8865);
                    }
                    else
                    {
                        _8886 = _8879;
                    }
                    _14101 = _8886;
                    break;
                } while(false);
                bool _14108;
                do
                {
                    bool _9166 = all(bool2(_14048.x > 0.0f.xx.x, _14048.y > 0.0f.xx.y));
                    bool _9172;
                    if (_9166)
                    {
                        _9172 = all(bool2(_14048.x < 1.0f.xx.x, _14048.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9172 = _9166;
                    }
                    if (!_9172)
                    {
                        _14108 = false;
                        break;
                    }
                    uint _9179_dummy_parameter;
                    float4x4 _14106;
                    do
                    {
                        float4x4 _9193;
                        bool _14105;
                        do
                        {
                            _9193 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14105 = false;
                                break;
                            }
                            uint _9227 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9227 + 32u) * 4 + 0) != 1u)
                            {
                                _14105 = false;
                                break;
                            }
                            uint _14102;
                            _14102 = 0u;
                            for (; _14102 < 4u; _14102++)
                            {
                                for (uint _14103 = 0u; _14103 < 4u; )
                                {
                                    _9193[_14102][_14103] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9227 + (_14102 * 4u)) + _14103) * 4 + 0));
                                    _14103++;
                                    continue;
                                }
                            }
                            _14105 = true;
                            break;
                        } while(false);
                        if (_14105)
                        {
                            _14106 = _9193;
                            break;
                        }
                        _14106 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14107;
                    do
                    {
                        float _9307 = 1.0f - _14048.y;
                        float4 _9318 = mul(float4((float2(_14048.x, _9307) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14048 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9179_dummy_parameter))))), 0)).x, 1.0f), _14106);
                        float _9320 = _9318.w;
                        if (!(_9320 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14107 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9333 = ((_9318.xy / _9320.xx) + 1.0f.xx) * 0.5f;
                        _14107 = float2(_9333.x - _14048.x, _9307 - _9333.y);
                        break;
                    } while(false);
                    float2 _9130 = abs(_14107);
                    if (any(bool2(_9130.x > 100000.0f.xx.x, _9130.y > 100000.0f.xx.y)))
                    {
                        _14108 = false;
                        break;
                    }
                    float _9138 = length(_14107 * _4770);
                    uint _9353_dummy_parameter;
                    bool _9152 = _9138 > ((8.0f * _4770.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9159;
                    if (_9152)
                    {
                        _9159 = length((r_motion_tp1.Load(int3(int2(floor(_14048 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9353_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4770) < (0.20000000298023223876953125f * _9138);
                    }
                    else
                    {
                        _9159 = _9152;
                    }
                    _14108 = _9159;
                    break;
                } while(false);
                bool _14115;
                do
                {
                    bool _9439 = all(bool2(_14049.x > 0.0f.xx.x, _14049.y > 0.0f.xx.y));
                    bool _9445;
                    if (_9439)
                    {
                        _9445 = all(bool2(_14049.x < 1.0f.xx.x, _14049.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9445 = _9439;
                    }
                    if (!_9445)
                    {
                        _14115 = false;
                        break;
                    }
                    uint _9452_dummy_parameter;
                    float4x4 _14113;
                    do
                    {
                        float4x4 _9466;
                        bool _14112;
                        do
                        {
                            _9466 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14112 = false;
                                break;
                            }
                            uint _9500 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9500 + 32u) * 4 + 0) != 1u)
                            {
                                _14112 = false;
                                break;
                            }
                            uint _14109;
                            _14109 = 0u;
                            for (; _14109 < 4u; _14109++)
                            {
                                for (uint _14110 = 0u; _14110 < 4u; )
                                {
                                    _9466[_14109][_14110] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9500 + (_14109 * 4u)) + _14110) * 4 + 0));
                                    _14110++;
                                    continue;
                                }
                            }
                            _14112 = true;
                            break;
                        } while(false);
                        if (_14112)
                        {
                            _14113 = _9466;
                            break;
                        }
                        _14113 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14114;
                    do
                    {
                        float _9580 = 1.0f - _14049.y;
                        float4 _9591 = mul(float4((float2(_14049.x, _9580) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9452_dummy_parameter))))), 0)).x, 1.0f), _14113);
                        float _9593 = _9591.w;
                        if (!(_9593 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14114 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9606 = ((_9591.xy / _9593.xx) + 1.0f.xx) * 0.5f;
                        _14114 = float2(_9606.x - _14049.x, _9580 - _9606.y);
                        break;
                    } while(false);
                    float2 _9403 = abs(_14114);
                    if (any(bool2(_9403.x > 100000.0f.xx.x, _9403.y > 100000.0f.xx.y)))
                    {
                        _14115 = false;
                        break;
                    }
                    float _9411 = length(_14114 * _4770);
                    uint _9626_dummy_parameter;
                    bool _9425 = _9411 > ((8.0f * _4770.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9432;
                    if (_9425)
                    {
                        _9432 = length((r_motion_tp1.Load(int3(int2(floor(_14049 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9626_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4770) < (0.20000000298023223876953125f * _9411);
                    }
                    else
                    {
                        _9432 = _9425;
                    }
                    _14115 = _9432;
                    break;
                } while(false);
                float4 _4838 = _7448 * float4(_14094 ? 0.0f : 1.0f, _14101 ? 0.0f : 1.0f, _14108 ? 0.0f : 1.0f, _14115 ? 0.0f : 1.0f);
                float _4840 = dot(_4838, 1.0f.xxxx);
                float4 _14258;
                if (_4840 > 0.001000000047497451305389404296875f)
                {
                    _14258 = _4838 / _4840.xxxx;
                }
                else
                {
                    _14258 = _7448;
                }
                _14257 = _14258;
            }
            else
            {
                _14257 = _7448;
            }
            _15564 = _4811;
            _14256 = _14257;
        }
        else
        {
            _15564 = 0.0f;
            _14256 = _7448;
        }
        bool _4857 = _4549 && (!_14185);
        bool _4866;
        if (_4857)
        {
            _4866 = (_14256.z + _14256.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4866 = _4857;
        }
        bool _4877;
        if (_4866)
        {
            _4877 = length((_14048 - _14045) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4877 = _4866;
        }
        bool _14345;
        if (_4877)
        {
            uint4 _9655 = r_warped_motion_qdata_tp1.Load(int3(_14266, 0));
            uint _9656 = _9655.x;
            bool _14348;
            if (_9656 != 0u)
            {
                float _14334;
                if (_9656 == 0u)
                {
                    _14334 = -1.0f;
                }
                else
                {
                    _14334 = float((_9656 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4887 = _14334 - 0.12000000476837158203125f;
                bool _9675 = all(bool2(_14048.x > 0.0f.xx.x, _14048.y > 0.0f.xx.y));
                bool _9681;
                if (_9675)
                {
                    _9681 = all(bool2(_14048.x < 1.0f.xx.x, _14048.y < 1.0f.xx.y));
                }
                else
                {
                    _9681 = _9675;
                }
                bool _4897;
                if (_9681)
                {
                    uint _9688_dummy_parameter;
                    _4897 = (log(((r_depth_tm1.Load(int3(int2(floor(_14048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9688_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4887;
                }
                else
                {
                    _4897 = _9681;
                }
                bool _4911;
                if (!_4897)
                {
                    bool _9718 = all(bool2(_14049.x > 0.0f.xx.x, _14049.y > 0.0f.xx.y));
                    bool _9724;
                    if (_9718)
                    {
                        _9724 = all(bool2(_14049.x < 1.0f.xx.x, _14049.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9724 = _9718;
                    }
                    bool _4909;
                    if (_9724)
                    {
                        uint _9731_dummy_parameter;
                        _4909 = (log(((r_depth_tp1.Load(int3(int2(floor(_14049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9731_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4887;
                    }
                    else
                    {
                        _4909 = _9724;
                    }
                    _4911 = _4909;
                }
                else
                {
                    _4911 = _4897;
                }
                _14348 = _4911;
            }
            else
            {
                _14348 = false;
            }
            _14345 = _14348;
        }
        else
        {
            _14345 = false;
        }
        bool _4916 = _14185 || _14345;
        bool _4921;
        if (_4916)
        {
            bool _9761 = all(bool2(_14045.x > 0.0f.xx.x, _14045.y > 0.0f.xx.y));
            bool _9767;
            if (_9761)
            {
                _9767 = all(bool2(_14045.x < 1.0f.xx.x, _14045.y < 1.0f.xx.y));
            }
            else
            {
                _9767 = _9761;
            }
            _4921 = _9767;
        }
        else
        {
            _4921 = _4916;
        }
        bool _4926;
        if (_4921)
        {
            bool _9772 = all(bool2(_14047.x > 0.0f.xx.x, _14047.y > 0.0f.xx.y));
            bool _9778;
            if (_9772)
            {
                _9778 = all(bool2(_14047.x < 1.0f.xx.x, _14047.y < 1.0f.xx.y));
            }
            else
            {
                _9778 = _9772;
            }
            _4926 = _9778;
        }
        else
        {
            _4926 = _4921;
        }
        float4 _14468;
        if (_4926)
        {
            float _4932 = _14256.x + _14256.y;
            float _4937 = _14256.z + _14256.w;
            float _14363;
            if (_4932 > 0.001000000047497451305389404296875f)
            {
                _14363 = _14256.x / _4932;
            }
            else
            {
                _14363 = _4737;
            }
            _14468 = float4(_14256.x + (_4937 * _14363), _14256.y + (_4937 * (1.0f - _14363)), 0.0f, 0.0f);
        }
        else
        {
            _14468 = _14256;
        }
        bool _9806 = (cbFI_pad0 & 1024u) != 0u;
        bool _9782 = !_9806;
        bool _9783 = !_9782;
        bool _9800;
        if (_9783)
        {
            _9800 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_14266.y * cbFI_MvDepthLaneSize.x) + _14266.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _9800 = _9782;
        }
        bool _9832;
        if (_9783)
        {
            _9832 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4528.y * cbFI_FlowLaneSize.x) + _4528.x)) * 4 + 0) != 0u;
        }
        else
        {
            _9832 = _9782;
        }
        float _4972 = float(_9832);
        bool _14489;
        float4 _14528;
        float3 _16197;
        if (_9806)
        {
            bool _4982;
            if (_9800)
            {
                _4982 = all(bool2(_14045.x > 0.0f.xx.x, _14045.y > 0.0f.xx.y));
            }
            else
            {
                _4982 = _9800;
            }
            bool _4988;
            if (_4982)
            {
                _4988 = all(bool2(_14045.x < 1.0f.xx.x, _14045.y < 1.0f.xx.y));
            }
            else
            {
                _4988 = _4982;
            }
            bool _4995;
            if (_9800)
            {
                _4995 = all(bool2(_14047.x > 0.0f.xx.x, _14047.y > 0.0f.xx.y));
            }
            else
            {
                _4995 = _9800;
            }
            bool _5001;
            if (_4995)
            {
                _5001 = all(bool2(_14047.x < 1.0f.xx.x, _14047.y < 1.0f.xx.y));
            }
            else
            {
                _5001 = _4995;
            }
            bool _5008;
            if (_9832)
            {
                _5008 = all(bool2(_14048.x > 0.0f.xx.x, _14048.y > 0.0f.xx.y));
            }
            else
            {
                _5008 = _9832;
            }
            bool _5014;
            if (_5008)
            {
                _5014 = all(bool2(_14048.x < 1.0f.xx.x, _14048.y < 1.0f.xx.y));
            }
            else
            {
                _5014 = _5008;
            }
            bool _5021;
            if (_9832)
            {
                _5021 = all(bool2(_14049.x > 0.0f.xx.x, _14049.y > 0.0f.xx.y));
            }
            else
            {
                _5021 = _9832;
            }
            bool _5027;
            if (_5021)
            {
                _5027 = all(bool2(_14049.x < 1.0f.xx.x, _14049.y < 1.0f.xx.y));
            }
            else
            {
                _5027 = _5021;
            }
            bool _5029 = !_9800;
            if (_5029)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9874;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _9874);
                }
            }
            bool _5034 = !_9832;
            if (_5034)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9884;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _9884);
                }
            }
            if (_9800 && _5034)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9894;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _9894);
                }
            }
            if (_5029 && _9832)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9904;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _9904);
                }
            }
            float _5053 = float(_4988);
            float _5055 = float(_5001);
            bool _5058 = _5014 && _5027;
            float _14397;
            if (_5058)
            {
                _14397 = 1.0f;
            }
            else
            {
                _14397 = (_5014 || _5027) ? 0.5f : 0.0f;
            }
            bool _14412;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4988)) && (!_5001))
            {
                bool _5088;
                if (_5058)
                {
                    float _14405;
                    do
                    {
                        bool _9988 = all(bool2(_14048.x > 0.0f.xx.x, _14048.y > 0.0f.xx.y));
                        bool _9994;
                        if (_9988)
                        {
                            _9994 = all(bool2(_14048.x < 1.0f.xx.x, _14048.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _9994 = _9988;
                        }
                        bool _9925 = !_9994;
                        bool _9932;
                        if (!_9925)
                        {
                            bool _9999 = all(bool2(_14049.x > 0.0f.xx.x, _14049.y > 0.0f.xx.y));
                            bool _10005;
                            if (_9999)
                            {
                                _10005 = all(bool2(_14049.x < 1.0f.xx.x, _14049.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _10005 = _9999;
                            }
                            _9932 = !_10005;
                        }
                        else
                        {
                            _9932 = _9925;
                        }
                        if (_9932)
                        {
                            _14405 = 0.0f;
                            break;
                        }
                        uint _10012_dummy_parameter;
                        uint _10028_dummy_parameter;
                        float4x4 _14404;
                        do
                        {
                            float4x4 _10042;
                            bool _14403;
                            do
                            {
                                _10042 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _14403 = false;
                                    break;
                                }
                                uint _10076 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_10076 + 32u) * 4 + 0) != 1u)
                                {
                                    _14403 = false;
                                    break;
                                }
                                uint _14400;
                                _14400 = 0u;
                                for (; _14400 < 4u; _14400++)
                                {
                                    for (uint _14401 = 0u; _14401 < 4u; )
                                    {
                                        _10042[_14400][_14401] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10076 + 16u) + (_14400 * 4u)) + _14401) * 4 + 0));
                                        _14401++;
                                        continue;
                                    }
                                }
                                _14403 = true;
                                break;
                            } while(false);
                            if (_14403)
                            {
                                _14404 = _10042;
                                break;
                            }
                            _14404 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _9953 = mul(float4((float2(_14048.x, 1.0f - _14048.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10012_dummy_parameter))))), 0)).x, 1.0f), _14404);
                        float _9955 = _9953.w;
                        if (abs(_9955) < 9.9999999747524270787835121154785e-07f)
                        {
                            _14405 = 0.0f;
                            break;
                        }
                        float _9966 = abs(cbFI_DeviceToViewDepth.y / ((_9953.z / _9955) - cbFI_DeviceToViewDepth.x));
                        float _9969 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10028_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _14405 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9966 - _9969) / max(max(_9966, _9969), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5088 = _14405 >= 0.5f;
                }
                else
                {
                    _5088 = _5058;
                }
                bool _5096;
                if (_5088)
                {
                    _5096 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5096 = _5088;
                }
                bool _14413;
                if (_5096)
                {
                    uint _10180_dummy_parameter;
                    float4x4 _14410;
                    do
                    {
                        float4x4 _10194;
                        bool _14409;
                        do
                        {
                            _10194 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14409 = false;
                                break;
                            }
                            uint _10228 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10228 + 32u) * 4 + 0) != 1u)
                            {
                                _14409 = false;
                                break;
                            }
                            uint _14406;
                            _14406 = 0u;
                            for (; _14406 < 4u; _14406++)
                            {
                                for (uint _14407 = 0u; _14407 < 4u; )
                                {
                                    _10194[_14406][_14407] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10228 + 16u) + (_14406 * 4u)) + _14407) * 4 + 0));
                                    _14407++;
                                    continue;
                                }
                            }
                            _14409 = true;
                            break;
                        } while(false);
                        if (_14409)
                        {
                            _14410 = _10194;
                            break;
                        }
                        _14410 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _14411;
                    do
                    {
                        float _10308 = 1.0f - _14048.y;
                        float4 _10319 = mul(float4((float2(_14048.x, _10308) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10180_dummy_parameter))))), 0)).x, 1.0f), _14410);
                        float _10321 = _10319.w;
                        if (!(_10321 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14411 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10334 = ((_10319.xy / _10321.xx) + 1.0f.xx) * 0.5f;
                        _14411 = float2(_10334.x - _14048.x, _10308 - _10334.y);
                        break;
                    } while(false);
                    float2 _5109 = float2(cbFI_DisplaySize);
                    _14413 = length(((_14048 + _14411) - _14049) * _5109) <= ((0.100000001490116119384765625f * length(_14411 * _5109)) + 8.0f);
                }
                else
                {
                    _14413 = _5088;
                }
                _14412 = _14413;
            }
            else
            {
                _14412 = true;
            }
            bool _5123 = !_14412;
            bool _17134 = _5123 ? false : _5027;
            bool _17135 = _5123 ? false : _5014;
            bool _14490;
            float4 _14529;
            if (!(((_4988 && _5001) && _17135) && _17134))
            {
                float4 _5145 = _14468 * float4(_5053, _5055, float(_17135), float(_17134));
                float _5147 = dot(_5145, 1.0f.xxxx);
                bool _5150 = !(_5147 > 0.0f);
                float4 _14530;
                if (!_5150)
                {
                    _14530 = _5145 / _5147.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _10356;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _10356);
                    }
                    _14530 = 0.0f.xxxx;
                }
                _14529 = _14530;
                _14490 = _5150;
            }
            else
            {
                _14529 = _14468;
                _14490 = false;
            }
            _16197 = float3(_5053, _5055, _14397);
            _14528 = _14529;
            _14489 = _14490;
        }
        else
        {
            _16197 = float3(float(_9800), _4972, 0.0f);
            _14528 = _14468;
            _14489 = false;
        }
        bool _5168 = !_14489;
        float4 _14621;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5168)
        {
            float _5175 = _14528.x + _14528.y;
            float4 _14622;
            if (_5175 > 0.001000000047497451305389404296875f)
            {
                _14622 = float4(_14528.x / _5175, _14528.y / _5175, 0.0f, 0.0f);
            }
            else
            {
                _14622 = float4(_4737, cbFI_Timestep, 0.0f, 0.0f);
            }
            _14621 = _14622;
        }
        else
        {
            _14621 = _14528;
        }
        float4 _14798;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5168) && _9800)
        {
            float _14595;
            do
            {
                uint4 _10496 = r_warped_motion_qdata_tp1.Load(int3(_14266, 0));
                uint _10497 = _10496.x;
                if (_10497 != 0u)
                {
                    float _14594;
                    if (_10497 == 0u)
                    {
                        _14594 = -1.0f;
                    }
                    else
                    {
                        _14594 = float((_10497 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14595 = _14594;
                    break;
                }
                int _14577;
                uint _14578;
                _14578 = _10497;
                _14577 = -1;
                uint _14593;
                for (; _14577 <= 1; _14578 = _14593, _14577++)
                {
                    _14593 = _14578;
                    for (int _14591 = -1; _14591 <= 1; )
                    {
                        _14593 = max(_14593, r_warped_motion_qdata_tp1.Load(int3(clamp(_14266 + int2(_14591, _14577), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _14591++;
                        continue;
                    }
                }
                if (_14578 != 0u)
                {
                    float _14590;
                    if (_14578 == 0u)
                    {
                        _14590 = -1.0f;
                    }
                    else
                    {
                        _14590 = float((_14578 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14595 = _14590;
                    break;
                }
                uint _14580;
                _14580 = 4294967295u;
                uint _17105;
                for (int _14579 = 0; _14579 < 8; _14580 = _17105, _14579++)
                {
                    int _14583 = 0;
                    for (;;)
                    {
                        if (_14583 < 5)
                        {
                            int2 _10447 = _14266 + (_1184[_14579] * _1193[_14583].xx);
                            bool _10450 = any(bool2(_10447.x < int2(0, 0).x, _10447.y < int2(0, 0).y));
                            bool _10458;
                            if (!_10450)
                            {
                                _10458 = any(bool2(_10447.x >= cbFI_MvDepthLaneSize.x, _10447.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _10458 = _10450;
                            }
                            if (_10458)
                            {
                                _17105 = _14580;
                                break;
                            }
                            uint4 _10536 = r_warped_motion_qdata_tp1.Load(int3(_10447, 0));
                            uint _10537 = _10536.x;
                            if (_10537 != 0u)
                            {
                                _17105 = min(_14580, _10537);
                                break;
                            }
                            _14583++;
                            continue;
                        }
                        else
                        {
                            _17105 = _14580;
                            break;
                        }
                    }
                }
                float _14582;
                if (_14580 == 4294967295u)
                {
                    _14582 = -1.0f;
                }
                else
                {
                    float _14581;
                    if (_14580 == 0u)
                    {
                        _14581 = -1.0f;
                    }
                    else
                    {
                        _14581 = float((_14580 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14582 = _14581;
                }
                _14595 = _14582;
                break;
            } while(false);
            float _5211 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5214 = r_warped_motion_qdata_tp1.Load(int3(_14266, 0)).x == 0u;
            bool _5220;
            if (_5214)
            {
                bool _10562 = all(bool2(_14045.x > 0.0f.xx.x, _14045.y > 0.0f.xx.y));
                bool _10568;
                if (_10562)
                {
                    _10568 = all(bool2(_14045.x < 1.0f.xx.x, _14045.y < 1.0f.xx.y));
                }
                else
                {
                    _10568 = _10562;
                }
                _5220 = _10568;
            }
            else
            {
                _5220 = _5214;
            }
            bool _5225;
            if (_5220)
            {
                bool _10573 = all(bool2(_14047.x > 0.0f.xx.x, _14047.y > 0.0f.xx.y));
                bool _10579;
                if (_10573)
                {
                    _10579 = all(bool2(_14047.x < 1.0f.xx.x, _14047.y < 1.0f.xx.y));
                }
                else
                {
                    _10579 = _10573;
                }
                _5225 = _10579;
            }
            else
            {
                _5225 = _5220;
            }
            bool _14607;
            float4 _14616;
            if (_5225)
            {
                uint _10586_dummy_parameter;
                float _10610 = log(((r_depth_tm1.Load(int3(int2(floor(_14045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10586_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _10618_dummy_parameter;
                float _10642 = log(((r_depth_tp1.Load(int3(int2(floor(_14047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10618_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _5236 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5243;
                if (_5236)
                {
                    _5243 = _10642 > (_10610 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5243 = _5236;
                }
                bool _14612;
                float4 _14634;
                if (_5243)
                {
                    _14634 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _14612 = true;
                }
                else
                {
                    bool _5249 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5256;
                    if (_5249)
                    {
                        _5256 = _10610 > (_10642 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5256 = _5249;
                    }
                    bool4 _17136 = _5256.xxxx;
                    _14634 = float4(_17136.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14621.x, _17136.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14621.y, _17136.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14621.z, _17136.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14621.w);
                    _14612 = _5256 ? true : false;
                }
                _14616 = _14634;
                _14607 = _14612;
            }
            else
            {
                _14616 = _14621;
                _14607 = false;
            }
            float4 _14689;
            if (_14607)
            {
                _14689 = 1.0f.xxxx;
            }
            else
            {
                bool _5267 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5273;
                if (_5267)
                {
                    _5273 = _14616.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5273 = _5267;
                }
                bool _5278;
                if (_5273)
                {
                    bool _10648 = all(bool2(_14047.x > 0.0f.xx.x, _14047.y > 0.0f.xx.y));
                    bool _10654;
                    if (_10648)
                    {
                        _10654 = all(bool2(_14047.x < 1.0f.xx.x, _14047.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10654 = _10648;
                    }
                    _5278 = _10654;
                }
                else
                {
                    _5278 = _5273;
                }
                float4 _14690;
                if (_5278)
                {
                    float _14643;
                    if (_14595 >= 0.0f)
                    {
                        _14643 = _14595 - _5211;
                    }
                    else
                    {
                        float _14639;
                        _14639 = 2.0f;
                        float _10711;
                        for (int _14638 = 0; _14638 < 24; _14639 = _10711, _14638++)
                        {
                            float _10675 = float(_14638 & 7) * 0.785398185253143310546875f;
                            int _10677 = _14638 >> 3;
                            int _14640;
                            if (_10677 == 0)
                            {
                                _14640 = 16;
                            }
                            else
                            {
                                _14640 = (_10677 == 1) ? 48 : 96;
                            }
                            uint _10743_dummy_parameter;
                            _10711 = min(_14639, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_14047 + ((cbFI_MvDepthLaneSizeRcp * float(_14640)) * float2(cos(_10675), sin(_10675))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10743_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14643 = _14639;
                    }
                    uint _10775_dummy_parameter;
                    float4 _14691;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_14047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10775_dummy_parameter))))), 0)).x) > ((exp((_14643 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _14691 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _14691 = 1.0f.xxxx;
                    }
                    _14690 = _14691;
                }
                else
                {
                    _14690 = 1.0f.xxxx;
                }
                _14689 = _14690;
            }
            bool _5306 = _14595 >= 0.0f;
            bool _5307 = (!_14607) && _5306;
            bool _5314;
            if (_5307)
            {
                _5314 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5314 = _5307;
            }
            bool _5320;
            if (_5314)
            {
                _5320 = _14616.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5320 = _5314;
            }
            bool _5325;
            if (_5320)
            {
                bool _10800 = all(bool2(_14045.x > 0.0f.xx.x, _14045.y > 0.0f.xx.y));
                bool _10806;
                if (_10800)
                {
                    _10806 = all(bool2(_14045.x < 1.0f.xx.x, _14045.y < 1.0f.xx.y));
                }
                else
                {
                    _10806 = _10800;
                }
                _5325 = _10806;
            }
            else
            {
                _5325 = _5320;
            }
            float4 _14714;
            if (_5325)
            {
                float _14683;
                if (_5306)
                {
                    _14683 = _14595 - _5211;
                }
                else
                {
                    float _14679;
                    _14679 = 2.0f;
                    float _10863;
                    for (int _14678 = 0; _14678 < 24; _14679 = _10863, _14678++)
                    {
                        float _10827 = float(_14678 & 7) * 0.785398185253143310546875f;
                        int _10829 = _14678 >> 3;
                        int _14680;
                        if (_10829 == 0)
                        {
                            _14680 = 16;
                        }
                        else
                        {
                            _14680 = (_10829 == 1) ? 48 : 96;
                        }
                        uint _10879_dummy_parameter;
                        _10863 = min(_14679, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_14045 + ((cbFI_MvDepthLaneSizeRcp * float(_14680)) * float2(cos(_10827), sin(_10827))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10879_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _14683 = _14679;
                }
                uint _10927_dummy_parameter;
                float4 _14715;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_14045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10927_dummy_parameter))))), 0)).x) > ((exp((_14683 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _13877 = _14689;
                    _13877.x = 0.0f;
                    _14715 = _13877;
                }
                else
                {
                    _14715 = _14689;
                }
                _14714 = _14715;
            }
            else
            {
                _14714 = _14689;
            }
            float4 _14727;
            if (_5307)
            {
                float _10954 = (exp(((_14595 - _5211) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5363 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5369;
                if (_5363)
                {
                    _5369 = _14616.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5369 = _5363;
                }
                bool _5374;
                if (_5369)
                {
                    bool _10959 = all(bool2(_14049.x > 0.0f.xx.x, _14049.y > 0.0f.xx.y));
                    bool _10965;
                    if (_10959)
                    {
                        _10965 = all(bool2(_14049.x < 1.0f.xx.x, _14049.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10965 = _10959;
                    }
                    _5374 = _10965;
                }
                else
                {
                    _5374 = _5369;
                }
                bool _5382;
                if (_5374)
                {
                    uint _10972_dummy_parameter;
                    _5382 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_14049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10972_dummy_parameter))))), 0)).x) > _10954;
                }
                else
                {
                    _5382 = _5374;
                }
                float4 _14725;
                if (_5382)
                {
                    float4 _13880 = _14714;
                    _13880.w = 0.0f;
                    _14725 = _13880;
                }
                else
                {
                    _14725 = _14714;
                }
                bool _5389 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5395;
                if (_5389)
                {
                    _5395 = _14616.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5395 = _5389;
                }
                bool _5400;
                if (_5395)
                {
                    bool _10990 = all(bool2(_14048.x > 0.0f.xx.x, _14048.y > 0.0f.xx.y));
                    bool _10996;
                    if (_10990)
                    {
                        _10996 = all(bool2(_14048.x < 1.0f.xx.x, _14048.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10996 = _10990;
                    }
                    _5400 = _10996;
                }
                else
                {
                    _5400 = _5395;
                }
                bool _5408;
                if (_5400)
                {
                    uint _11003_dummy_parameter;
                    _5408 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_14048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11003_dummy_parameter))))), 0)).x) > _10954;
                }
                else
                {
                    _5408 = _5400;
                }
                float4 _14728;
                if (_5408)
                {
                    float4 _13883 = _14725;
                    _13883.z = 0.0f;
                    _14728 = _13883;
                }
                else
                {
                    _14728 = _14725;
                }
                _14727 = _14728;
            }
            else
            {
                _14727 = _14714;
            }
            float4 _14799;
            if (any(bool4(_14727.x < 1.0f.xxxx.x, _14727.y < 1.0f.xxxx.y, _14727.z < 1.0f.xxxx.z, _14727.w < 1.0f.xxxx.w)))
            {
                float4 _5419 = _14616 * _14727;
                float _5421 = dot(_5419, 1.0f.xxxx);
                float4 _14800;
                if (_5421 > 0.0f)
                {
                    _14800 = _5419 / _5421.xxxx;
                }
                else
                {
                    bool _5432 = _14727.y == 0.0f;
                    bool _5438;
                    if (_5432)
                    {
                        _5438 = _14727.x > 0.0f;
                    }
                    else
                    {
                        _5438 = _5432;
                    }
                    bool _5443;
                    if (_5438)
                    {
                        bool _11021 = all(bool2(_14045.x > 0.0f.xx.x, _14045.y > 0.0f.xx.y));
                        bool _11027;
                        if (_11021)
                        {
                            _11027 = all(bool2(_14045.x < 1.0f.xx.x, _14045.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11027 = _11021;
                        }
                        _5443 = _11027;
                    }
                    else
                    {
                        _5443 = _5438;
                    }
                    float4 _14801;
                    if (_5443)
                    {
                        _14801 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5448 = _14727.x == 0.0f;
                        bool _5454;
                        if (_5448)
                        {
                            _5454 = _14727.y > 0.0f;
                        }
                        else
                        {
                            _5454 = _5448;
                        }
                        bool _5459;
                        if (_5454)
                        {
                            bool _11032 = all(bool2(_14047.x > 0.0f.xx.x, _14047.y > 0.0f.xx.y));
                            bool _11038;
                            if (_11032)
                            {
                                _11038 = all(bool2(_14047.x < 1.0f.xx.x, _14047.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11038 = _11032;
                            }
                            _5459 = _11038;
                        }
                        else
                        {
                            _5459 = _5454;
                        }
                        bool4 _17139 = _5459.xxxx;
                        _14801 = float4(_17139.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14616.x, _17139.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14616.y, _17139.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14616.z, _17139.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14616.w);
                    }
                    _14800 = _14801;
                }
                _14799 = _14800;
            }
            else
            {
                _14799 = _14616;
            }
            _14798 = _14799;
        }
        else
        {
            _14798 = _14621;
        }
        float4 _15528;
        bool _15834;
        float3 _15967;
        if (((cbFI_pad0 & 32768u) != 0u) && _5168)
        {
            bool _5476 = _14798.x > 0.00999999977648258209228515625f;
            bool _5479 = _14798.y > 0.00999999977648258209228515625f;
            bool _5488 = (_14798.z + _14798.w) > 0.0199999995529651641845703125f;
            bool _5494;
            if (_5488)
            {
                bool _11043 = all(bool2(_14048.x > 0.0f.xx.x, _14048.y > 0.0f.xx.y));
                bool _11049;
                if (_11043)
                {
                    _11049 = all(bool2(_14048.x < 1.0f.xx.x, _14048.y < 1.0f.xx.y));
                }
                else
                {
                    _11049 = _11043;
                }
                _5494 = _11049;
            }
            else
            {
                _5494 = _5488;
            }
            bool _5499;
            if (_5494)
            {
                bool _11054 = all(bool2(_14049.x > 0.0f.xx.x, _14049.y > 0.0f.xx.y));
                bool _11060;
                if (_11054)
                {
                    _11060 = all(bool2(_14049.x < 1.0f.xx.x, _14049.y < 1.0f.xx.y));
                }
                else
                {
                    _11060 = _11054;
                }
                _5499 = _11060;
            }
            else
            {
                _5499 = _5494;
            }
            bool _5506;
            if (_5499)
            {
                float _14814;
                do
                {
                    bool _11143 = all(bool2(_14048.x > 0.0f.xx.x, _14048.y > 0.0f.xx.y));
                    bool _11149;
                    if (_11143)
                    {
                        _11149 = all(bool2(_14048.x < 1.0f.xx.x, _14048.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11149 = _11143;
                    }
                    bool _11080 = !_11149;
                    bool _11087;
                    if (!_11080)
                    {
                        bool _11154 = all(bool2(_14049.x > 0.0f.xx.x, _14049.y > 0.0f.xx.y));
                        bool _11160;
                        if (_11154)
                        {
                            _11160 = all(bool2(_14049.x < 1.0f.xx.x, _14049.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11160 = _11154;
                        }
                        _11087 = !_11160;
                    }
                    else
                    {
                        _11087 = _11080;
                    }
                    if (_11087)
                    {
                        _14814 = 0.0f;
                        break;
                    }
                    uint _11167_dummy_parameter;
                    uint _11183_dummy_parameter;
                    float4x4 _14813;
                    do
                    {
                        float4x4 _11197;
                        bool _14812;
                        do
                        {
                            _11197 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14812 = false;
                                break;
                            }
                            uint _11231 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11231 + 32u) * 4 + 0) != 1u)
                            {
                                _14812 = false;
                                break;
                            }
                            uint _14809;
                            _14809 = 0u;
                            for (; _14809 < 4u; _14809++)
                            {
                                for (uint _14810 = 0u; _14810 < 4u; )
                                {
                                    _11197[_14809][_14810] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11231 + 16u) + (_14809 * 4u)) + _14810) * 4 + 0));
                                    _14810++;
                                    continue;
                                }
                            }
                            _14812 = true;
                            break;
                        } while(false);
                        if (_14812)
                        {
                            _14813 = _11197;
                            break;
                        }
                        _14813 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _11108 = mul(float4((float2(_14048.x, 1.0f - _14048.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11167_dummy_parameter))))), 0)).x, 1.0f), _14813);
                    float _11110 = _11108.w;
                    if (abs(_11110) < 9.9999999747524270787835121154785e-07f)
                    {
                        _14814 = 0.0f;
                        break;
                    }
                    float _11121 = abs(cbFI_DeviceToViewDepth.y / ((_11108.z / _11110) - cbFI_DeviceToViewDepth.x));
                    float _11124 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11183_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _14814 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11121 - _11124) / max(max(_11121, _11124), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5506 = _14814 < 0.5f;
            }
            else
            {
                _5506 = _5499;
            }
            float4 _14833;
            if (_5506)
            {
                uint _11335_dummy_parameter;
                uint _11366_dummy_parameter;
                float4 _14834;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_14048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11335_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11366_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _14834 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _14834 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _14833 = _14834;
            }
            else
            {
                _14833 = 1.0f.xxxx;
            }
            bool _5530;
            if (_9800)
            {
                bool _11395 = all(bool2(_14045.x > 0.0f.xx.x, _14045.y > 0.0f.xx.y));
                bool _11401;
                if (_11395)
                {
                    _11401 = all(bool2(_14045.x < 1.0f.xx.x, _14045.y < 1.0f.xx.y));
                }
                else
                {
                    _11401 = _11395;
                }
                _5530 = _11401;
            }
            else
            {
                _5530 = _9800;
            }
            bool _5536;
            if (_9800)
            {
                bool _11406 = all(bool2(_14047.x > 0.0f.xx.x, _14047.y > 0.0f.xx.y));
                bool _11412;
                if (_11406)
                {
                    _11412 = all(bool2(_14047.x < 1.0f.xx.x, _14047.y < 1.0f.xx.y));
                }
                else
                {
                    _11412 = _11406;
                }
                _5536 = _11412;
            }
            else
            {
                _5536 = _9800;
            }
            bool _5542;
            if (_9832)
            {
                bool _11417 = all(bool2(_14048.x > 0.0f.xx.x, _14048.y > 0.0f.xx.y));
                bool _11423;
                if (_11417)
                {
                    _11423 = all(bool2(_14048.x < 1.0f.xx.x, _14048.y < 1.0f.xx.y));
                }
                else
                {
                    _11423 = _11417;
                }
                _5542 = _11423;
            }
            else
            {
                _5542 = _9832;
            }
            bool _5548;
            if (_9832)
            {
                bool _11428 = all(bool2(_14049.x > 0.0f.xx.x, _14049.y > 0.0f.xx.y));
                bool _11434;
                if (_11428)
                {
                    _11434 = all(bool2(_14049.x < 1.0f.xx.x, _14049.y < 1.0f.xx.y));
                }
                else
                {
                    _11434 = _11428;
                }
                _5548 = _11434;
            }
            else
            {
                _5548 = _9832;
            }
            bool _5551 = _5542 != _5548;
            bool _5557;
            if (_5551)
            {
                _5557 = _5530 || _5536;
            }
            else
            {
                _5557 = _5551;
            }
            float4 _14936;
            if (_5557)
            {
                float4 _13910 = _14833;
                _13910.z = 0.0f;
                _13910.w = 0.0f;
                _14936 = _13910;
            }
            else
            {
                _14936 = _14833;
            }
            bool _5564 = _5530 && _5476;
            bool _5567 = _5536 && _5479;
            float4 _15041;
            float3 _16076;
            if (_5564 || _5567)
            {
                float _14931;
                do
                {
                    uint4 _11573 = r_warped_motion_qdata_tp1.Load(int3(_14266, 0));
                    uint _11574 = _11573.x;
                    if (_11574 != 0u)
                    {
                        float _14930;
                        if (_11574 == 0u)
                        {
                            _14930 = -1.0f;
                        }
                        else
                        {
                            _14930 = float((_11574 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _14931 = _14930;
                        break;
                    }
                    int _14913;
                    uint _14914;
                    _14914 = _11574;
                    _14913 = -1;
                    uint _14929;
                    for (; _14913 <= 1; _14914 = _14929, _14913++)
                    {
                        _14929 = _14914;
                        for (int _14927 = -1; _14927 <= 1; )
                        {
                            _14929 = max(_14929, r_warped_motion_qdata_tp1.Load(int3(clamp(_14266 + int2(_14927, _14913), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _14927++;
                            continue;
                        }
                    }
                    if (_14914 != 0u)
                    {
                        float _14926;
                        if (_14914 == 0u)
                        {
                            _14926 = -1.0f;
                        }
                        else
                        {
                            _14926 = float((_14914 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _14931 = _14926;
                        break;
                    }
                    uint _14916;
                    _14916 = 4294967295u;
                    uint _17106;
                    for (int _14915 = 0; _14915 < 8; _14916 = _17106, _14915++)
                    {
                        int _14919 = 0;
                        for (;;)
                        {
                            if (_14919 < 5)
                            {
                                int2 _11524 = _14266 + (_1184[_14915] * _1193[_14919].xx);
                                bool _11527 = any(bool2(_11524.x < int2(0, 0).x, _11524.y < int2(0, 0).y));
                                bool _11535;
                                if (!_11527)
                                {
                                    _11535 = any(bool2(_11524.x >= cbFI_MvDepthLaneSize.x, _11524.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _11535 = _11527;
                                }
                                if (_11535)
                                {
                                    _17106 = _14916;
                                    break;
                                }
                                uint4 _11613 = r_warped_motion_qdata_tp1.Load(int3(_11524, 0));
                                uint _11614 = _11613.x;
                                if (_11614 != 0u)
                                {
                                    _17106 = min(_14916, _11614);
                                    break;
                                }
                                _14919++;
                                continue;
                            }
                            else
                            {
                                _17106 = _14916;
                                break;
                            }
                        }
                    }
                    float _14918;
                    if (_14916 == 4294967295u)
                    {
                        _14918 = -1.0f;
                    }
                    else
                    {
                        float _14917;
                        if (_14916 == 0u)
                        {
                            _14917 = -1.0f;
                        }
                        else
                        {
                            _14917 = float((_14916 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _14918 = _14917;
                    }
                    _14931 = _14918;
                    break;
                } while(false);
                bool _5575 = _14931 < 0.0f;
                float _14932;
                if (_5575)
                {
                    _14932 = 0.0f;
                }
                else
                {
                    _14932 = _14931 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _11635_dummy_parameter;
                uint _11667_dummy_parameter;
                float4 _14969;
                if ((_5575 && _5564) && _5567)
                {
                    uint _11699_dummy_parameter;
                    float _11723 = log(((r_depth_tm1.Load(int3(int2(floor(_14045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11699_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _11731_dummy_parameter;
                    float _11755 = log(((r_depth_tp1.Load(int3(int2(floor(_14047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11731_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _14970;
                    if (_11723 > (_11755 + 0.07999999821186065673828125f))
                    {
                        float4 _13914 = _14936;
                        _13914.x = 0.0f;
                        _14970 = _13914;
                    }
                    else
                    {
                        float4 _14971;
                        if (_11755 > (_11723 + 0.07999999821186065673828125f))
                        {
                            float4 _13916 = _14936;
                            _13916.y = 0.0f;
                            _14971 = _13916;
                        }
                        else
                        {
                            _14971 = _14936;
                        }
                        _14970 = _14971;
                    }
                    _14969 = _14970;
                }
                else
                {
                    _14969 = _14936;
                }
                float _5627 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5629 = _14931 >= 0.0f;
                float _14952;
                if (_5629)
                {
                    _14952 = _14931 - _5627;
                }
                else
                {
                    float _14948;
                    if (_5564)
                    {
                        float _14947;
                        _14947 = 2.0f;
                        float _11813;
                        for (int _14946 = 0; _14946 < 24; _14947 = _11813, _14946++)
                        {
                            float _11777 = float(_14946 & 7) * 0.785398185253143310546875f;
                            int _11779 = _14946 >> 3;
                            int _14949;
                            if (_11779 == 0)
                            {
                                _14949 = 16;
                            }
                            else
                            {
                                _14949 = (_11779 == 1) ? 48 : 96;
                            }
                            uint _11829_dummy_parameter;
                            _11813 = min(_14947, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_14045 + ((cbFI_MvDepthLaneSizeRcp * float(_14949)) * float2(cos(_11777), sin(_11777))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11829_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14948 = _14947;
                    }
                    else
                    {
                        _14948 = 0.0f;
                    }
                    _14952 = _14948;
                }
                float _14959;
                if (_5629)
                {
                    _14959 = _14931 - _5627;
                }
                else
                {
                    float _14955;
                    if (_5567)
                    {
                        float _14954;
                        _14954 = 2.0f;
                        float _11927;
                        for (int _14953 = 0; _14953 < 24; _14954 = _11927, _14953++)
                        {
                            float _11891 = float(_14953 & 7) * 0.785398185253143310546875f;
                            int _11893 = _14953 >> 3;
                            int _14956;
                            if (_11893 == 0)
                            {
                                _14956 = 16;
                            }
                            else
                            {
                                _14956 = (_11893 == 1) ? 48 : 96;
                            }
                            uint _11959_dummy_parameter;
                            _11927 = min(_14954, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_14047 + ((cbFI_MvDepthLaneSizeRcp * float(_14956)) * float2(cos(_11891), sin(_11891))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11959_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14955 = _14954;
                    }
                    else
                    {
                        _14955 = 0.0f;
                    }
                    _14959 = _14955;
                }
                float _14960;
                if (_5564)
                {
                    uint _11991_dummy_parameter;
                    _14960 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_14045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11991_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _14960 = 0.0f;
                }
                float _14961;
                if (_5567)
                {
                    uint _12011_dummy_parameter;
                    _14961 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_14047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12011_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _14961 = 0.0f;
                }
                bool _5684;
                if (_5564)
                {
                    _5684 = _14960 > ((exp((_14952 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5684 = _5564;
                }
                float4 _14977;
                if (_5684)
                {
                    float4 _13918 = _14969;
                    _13918.x = 0.0f;
                    _14977 = _13918;
                }
                else
                {
                    _14977 = _14969;
                }
                bool _5696;
                if (_5567)
                {
                    _5696 = _14961 > ((exp((_14959 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5696 = _5567;
                }
                float4 _14979;
                if (_5696)
                {
                    float4 _13920 = _14977;
                    _13920.y = 0.0f;
                    _14979 = _13920;
                }
                else
                {
                    _14979 = _14977;
                }
                float4 _15042;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5629)
                {
                    bool _5716;
                    if (_5564)
                    {
                        _5716 = _14960 < ((exp((_14952 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5716 = _5564;
                    }
                    float4 _14981;
                    if (_5716)
                    {
                        float4 _13922 = _14979;
                        _13922.x = 0.0f;
                        _14981 = _13922;
                    }
                    else
                    {
                        _14981 = _14979;
                    }
                    bool _5728;
                    if (_5567)
                    {
                        _5728 = _14961 < ((exp((_14959 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5728 = _5567;
                    }
                    float4 _15043;
                    if (_5728)
                    {
                        float4 _13924 = _14981;
                        _13924.y = 0.0f;
                        _15043 = _13924;
                    }
                    else
                    {
                        _15043 = _14981;
                    }
                    _15042 = _15043;
                }
                else
                {
                    _15042 = _14979;
                }
                _16076 = float3(_14932, log(((r_depth_tm1.Load(int3(int2(floor(_14045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11635_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_14047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11667_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _15041 = _15042;
            }
            else
            {
                _16076 = float3(0.0f, 0.0f, 0.5f);
                _15041 = _14936;
            }
            bool _5739 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5488;
            bool _5745;
            if (_5739)
            {
                _5745 = _5542 || _5548;
            }
            else
            {
                _5745 = _5739;
            }
            float4 _15084;
            if (_5745)
            {
                float _15036;
                do
                {
                    uint4 _12191 = r_warped_motion_qdata_tp1.Load(int3(_14266, 0));
                    uint _12192 = _12191.x;
                    if (_12192 != 0u)
                    {
                        float _15035;
                        if (_12192 == 0u)
                        {
                            _15035 = -1.0f;
                        }
                        else
                        {
                            _15035 = float((_12192 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15036 = _15035;
                        break;
                    }
                    int _15018;
                    uint _15019;
                    _15019 = _12192;
                    _15018 = -1;
                    uint _15034;
                    for (; _15018 <= 1; _15019 = _15034, _15018++)
                    {
                        _15034 = _15019;
                        for (int _15032 = -1; _15032 <= 1; )
                        {
                            _15034 = max(_15034, r_warped_motion_qdata_tp1.Load(int3(clamp(_14266 + int2(_15032, _15018), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15032++;
                            continue;
                        }
                    }
                    if (_15019 != 0u)
                    {
                        float _15031;
                        if (_15019 == 0u)
                        {
                            _15031 = -1.0f;
                        }
                        else
                        {
                            _15031 = float((_15019 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15036 = _15031;
                        break;
                    }
                    uint _15021;
                    _15021 = 4294967295u;
                    uint _17107;
                    for (int _15020 = 0; _15020 < 8; _15021 = _17107, _15020++)
                    {
                        int _15024 = 0;
                        for (;;)
                        {
                            if (_15024 < 5)
                            {
                                int2 _12142 = _14266 + (_1184[_15020] * _1193[_15024].xx);
                                bool _12145 = any(bool2(_12142.x < int2(0, 0).x, _12142.y < int2(0, 0).y));
                                bool _12153;
                                if (!_12145)
                                {
                                    _12153 = any(bool2(_12142.x >= cbFI_MvDepthLaneSize.x, _12142.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12153 = _12145;
                                }
                                if (_12153)
                                {
                                    _17107 = _15021;
                                    break;
                                }
                                uint4 _12231 = r_warped_motion_qdata_tp1.Load(int3(_12142, 0));
                                uint _12232 = _12231.x;
                                if (_12232 != 0u)
                                {
                                    _17107 = min(_15021, _12232);
                                    break;
                                }
                                _15024++;
                                continue;
                            }
                            else
                            {
                                _17107 = _15021;
                                break;
                            }
                        }
                    }
                    float _15023;
                    if (_15021 == 4294967295u)
                    {
                        _15023 = -1.0f;
                    }
                    else
                    {
                        float _15022;
                        if (_15021 == 0u)
                        {
                            _15022 = -1.0f;
                        }
                        else
                        {
                            _15022 = float((_15021 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15023 = _15022;
                    }
                    _15036 = _15023;
                    break;
                } while(false);
                float4 _15085;
                if (_15036 >= 0.0f)
                {
                    float _12253 = (exp((_15036 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5764;
                    if (_5542)
                    {
                        uint _12260_dummy_parameter;
                        _5764 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_14048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12260_dummy_parameter))))), 0)).x) > _12253;
                    }
                    else
                    {
                        _5764 = _5542;
                    }
                    float4 _15054;
                    if (_5764)
                    {
                        float4 _13926 = _15041;
                        _13926.z = 0.0f;
                        _15054 = _13926;
                    }
                    else
                    {
                        _15054 = _15041;
                    }
                    bool _5776;
                    if (_5548)
                    {
                        uint _12280_dummy_parameter;
                        _5776 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_14049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12280_dummy_parameter))))), 0)).x) > _12253;
                    }
                    else
                    {
                        _5776 = _5548;
                    }
                    float4 _15086;
                    if (_5776)
                    {
                        float4 _13928 = _15054;
                        _13928.w = 0.0f;
                        _15086 = _13928;
                    }
                    else
                    {
                        _15086 = _15054;
                    }
                    _15085 = _15086;
                }
                else
                {
                    _15085 = _15041;
                }
                _15084 = _15085;
            }
            else
            {
                _15084 = _15041;
            }
            bool _5784 = _5530 != _5536;
            bool _5791;
            if (_5784)
            {
                _5791 = _5530 ? _5476 : _5479;
            }
            else
            {
                _5791 = _5784;
            }
            bool _5798;
            if (_5791)
            {
                _5798 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5798 = _5791;
            }
            float4 _15187;
            if (_5798)
            {
                bool2 _5803 = _5530.xx;
                float2 _5804 = float2(_5803.x ? _14045.x : _14047.x, _5803.y ? _14045.y : _14047.y);
                float _15068;
                if (_5530)
                {
                    uint _12300_dummy_parameter;
                    _15068 = r_depth_tm1.Load(int3(int2(floor(_5804 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12300_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _12316_dummy_parameter;
                    _15068 = r_depth_tp1.Load(int3(int2(floor(_5804 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12316_dummy_parameter))))), 0)).x;
                }
                float4x4 _15075;
                if (_5530)
                {
                    float4x4 _15064;
                    do
                    {
                        float4x4 _12330;
                        bool _15063;
                        do
                        {
                            _12330 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15063 = false;
                                break;
                            }
                            uint _12364 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12364 + 32u) * 4 + 0) != 1u)
                            {
                                _15063 = false;
                                break;
                            }
                            uint _15060;
                            _15060 = 0u;
                            for (; _15060 < 4u; _15060++)
                            {
                                for (uint _15061 = 0u; _15061 < 4u; )
                                {
                                    _12330[_15060][_15061] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12364 + 16u) + (_15060 * 4u)) + _15061) * 4 + 0));
                                    _15061++;
                                    continue;
                                }
                            }
                            _15063 = true;
                            break;
                        } while(false);
                        if (_15063)
                        {
                            _15064 = _12330;
                            break;
                        }
                        _15064 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _15075 = _15064;
                }
                else
                {
                    float4x4 _15059;
                    do
                    {
                        float4x4 _12436;
                        bool _15058;
                        do
                        {
                            _12436 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15058 = false;
                                break;
                            }
                            uint _12470 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12470 + 32u) * 4 + 0) != 1u)
                            {
                                _15058 = false;
                                break;
                            }
                            uint _15055;
                            _15055 = 0u;
                            for (; _15055 < 4u; _15055++)
                            {
                                for (uint _15056 = 0u; _15056 < 4u; )
                                {
                                    _12436[_15055][_15056] = asfloat(rw_nfru_diagnostics.Load<uint>(((_12470 + (_15055 * 4u)) + _15056) * 4 + 0));
                                    _15056++;
                                    continue;
                                }
                            }
                            _15058 = true;
                            break;
                        } while(false);
                        if (_15058)
                        {
                            _15059 = _12436;
                            break;
                        }
                        _15059 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _15075 = _15059;
                }
                float2 _15076;
                do
                {
                    float _12547 = _5804.x;
                    float _12550 = 1.0f - _5804.y;
                    float4 _12561 = mul(float4((float2(_12547, _12550) * 2.0f) - 1.0f.xx, _15068, 1.0f), _15075);
                    float _12563 = _12561.w;
                    if (!(_12563 > 9.9999999747524270787835121154785e-07f))
                    {
                        _15076 = 1000000.0f.xx;
                        break;
                    }
                    float2 _12576 = ((_12561.xy / _12563.xx) + 1.0f.xx) * 0.5f;
                    _15076 = float2(_12576.x - _12547, _12550 - _12576.y);
                    break;
                } while(false);
                float2 _5834 = float2(cbFI_DisplaySize);
                float4 _15188;
                if (!(length(((_5804 + _15076) - float2(_5803.x ? _14047.x : _14045.x, _5803.y ? _14047.y : _14045.y)) * _5834) <= ((0.100000001490116119384765625f * length(_15076 * _5834)) + 8.0f)))
                {
                    float4 _15189;
                    if (_5530)
                    {
                        float4 _13938 = _15084;
                        _13938.x = 0.0f;
                        _15189 = _13938;
                    }
                    else
                    {
                        float4 _13940 = _15084;
                        _13940.y = 0.0f;
                        _15189 = _13940;
                    }
                    _15188 = _15189;
                }
                else
                {
                    _15188 = _15084;
                }
                _15187 = _15188;
            }
            else
            {
                _15187 = _15084;
            }
            float4 _5859 = _14798 * _15187;
            float _5861 = dot(_5859, 1.0f.xxxx);
            float4 _15529;
            bool _15835;
            if (_5861 > 0.0f)
            {
                _15835 = _14489;
                _15529 = _5859 / _5861.xxxx;
            }
            else
            {
                bool _5872 = any(bool4(_15187.x < 1.0f.xxxx.x, _15187.y < 1.0f.xxxx.y, _15187.z < 1.0f.xxxx.z, _15187.w < 1.0f.xxxx.w));
                if (_5872)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _12598;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _12598);
                    }
                }
                bool4 _17142 = _5872.xxxx;
                _15835 = _5872 ? true : _14489;
                _15529 = float4(_17142.x ? 0.0f.xxxx.x : _14798.x, _17142.y ? 0.0f.xxxx.y : _14798.y, _17142.z ? 0.0f.xxxx.z : _14798.z, _17142.w ? 0.0f.xxxx.w : _14798.w);
            }
            _15967 = _16076;
            _15834 = _15835;
            _15528 = _15529;
        }
        else
        {
            _15967 = float3(0.0f, 0.0f, 0.5f);
            _15834 = _14489;
            _15528 = _14798;
        }
        uint _5881 = (cbFI_pad0 >> 24u) & 31u;
        uint _5885 = (cbFI_pad0 >> 16u) & 255u;
        bool _5887 = _5881 != 0u;
        bool _5889 = _5885 == 12u;
        bool _5892 = _5885 == 13u;
        float4 _15549;
        if ((_5887 || _5889) || _5892)
        {
            float _15195;
            do
            {
                bool _12682 = all(bool2(_14048.x > 0.0f.xx.x, _14048.y > 0.0f.xx.y));
                bool _12688;
                if (_12682)
                {
                    _12688 = all(bool2(_14048.x < 1.0f.xx.x, _14048.y < 1.0f.xx.y));
                }
                else
                {
                    _12688 = _12682;
                }
                bool _12619 = !_12688;
                bool _12626;
                if (!_12619)
                {
                    bool _12693 = all(bool2(_14049.x > 0.0f.xx.x, _14049.y > 0.0f.xx.y));
                    bool _12699;
                    if (_12693)
                    {
                        _12699 = all(bool2(_14049.x < 1.0f.xx.x, _14049.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12699 = _12693;
                    }
                    _12626 = !_12699;
                }
                else
                {
                    _12626 = _12619;
                }
                if (_12626)
                {
                    _15195 = 0.0f;
                    break;
                }
                uint _12706_dummy_parameter;
                uint _12722_dummy_parameter;
                float4x4 _15194;
                do
                {
                    float4x4 _12736;
                    bool _15193;
                    do
                    {
                        _12736 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _15193 = false;
                            break;
                        }
                        uint _12770 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_12770 + 32u) * 4 + 0) != 1u)
                        {
                            _15193 = false;
                            break;
                        }
                        uint _15190;
                        _15190 = 0u;
                        for (; _15190 < 4u; _15190++)
                        {
                            for (uint _15191 = 0u; _15191 < 4u; )
                            {
                                _12736[_15190][_15191] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12770 + 16u) + (_15190 * 4u)) + _15191) * 4 + 0));
                                _15191++;
                                continue;
                            }
                        }
                        _15193 = true;
                        break;
                    } while(false);
                    if (_15193)
                    {
                        _15194 = _12736;
                        break;
                    }
                    _15194 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _12647 = mul(float4((float2(_14048.x, 1.0f - _14048.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12706_dummy_parameter))))), 0)).x, 1.0f), _15194);
                float _12649 = _12647.w;
                if (abs(_12649) < 9.9999999747524270787835121154785e-07f)
                {
                    _15195 = 0.0f;
                    break;
                }
                float _12660 = abs(cbFI_DeviceToViewDepth.y / ((_12647.z / _12649) - cbFI_DeviceToViewDepth.x));
                float _12663 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12722_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _15195 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12660 - _12663) / max(max(_12660, _12663), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _12872 = all(bool2(_14049.x > 0.0f.xx.x, _14049.y > 0.0f.xx.y));
            bool _12878;
            if (_12872)
            {
                _12878 = all(bool2(_14049.x < 1.0f.xx.x, _14049.y < 1.0f.xx.y));
            }
            else
            {
                _12878 = _12872;
            }
            float _15196;
            if (_12878)
            {
                uint _12885_dummy_parameter;
                _15196 = length((_6698 + (r_motion_tp1.Load(int3(int2(floor(_14049 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _12885_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _15196 = 1000000.0f;
            }
            float _15211;
            if ((_5881 & 1u) != 0u)
            {
                _15211 = _15195;
            }
            else
            {
                _15211 = 1.0f;
            }
            float _15212;
            if ((_5881 & 2u) != 0u)
            {
                _15212 = _15211 * (1.0f - smoothstep(2.0f, 8.0f, _15196));
            }
            else
            {
                _15212 = _15211;
            }
            float _15213;
            if ((_5881 & 4u) != 0u)
            {
                _15213 = _15212 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7419 - _7427) - length(_7403 - _7411))));
            }
            else
            {
                _15213 = _15212;
            }
            float _15543;
            if ((_5881 & 8u) != 0u)
            {
                _15543 = lerp(1.0f, _15213, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7403 - _7411)));
            }
            else
            {
                _15543 = _15213;
            }
            bool _5967 = (_5881 & 16u) != 0u;
            bool _5976;
            if (_5967)
            {
                _5976 = length(_14043 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5976 = _5967;
            }
            float _17144 = _5976 ? 1.0f : _15543;
            bool _5982 = _5887 && _9800;
            bool _5987;
            if (_5982)
            {
                bool _12910 = all(bool2(_14045.x > 0.0f.xx.x, _14045.y > 0.0f.xx.y));
                bool _12916;
                if (_12910)
                {
                    _12916 = all(bool2(_14045.x < 1.0f.xx.x, _14045.y < 1.0f.xx.y));
                }
                else
                {
                    _12916 = _12910;
                }
                _5987 = _12916;
            }
            else
            {
                _5987 = _5982;
            }
            bool _5992;
            if (_5987)
            {
                bool _12921 = all(bool2(_14047.x > 0.0f.xx.x, _14047.y > 0.0f.xx.y));
                bool _12927;
                if (_12921)
                {
                    _12927 = all(bool2(_14047.x < 1.0f.xx.x, _14047.y < 1.0f.xx.y));
                }
                else
                {
                    _12927 = _12921;
                }
                _5992 = _12927;
            }
            else
            {
                _5992 = _5987;
            }
            float4 _15550;
            if (_5992)
            {
                float _5998 = _15528.x + _15528.y;
                float _6007 = (_15528.z + _15528.w) * (1.0f - _17144);
                float _15546;
                if (_5998 > 9.9999997473787516355514526367188e-06f)
                {
                    _15546 = _15528.x / _5998;
                }
                else
                {
                    _15546 = _4737;
                }
                _15550 = float4(_15528.x + (_6007 * _15546), _15528.y + (_6007 * (1.0f - _15546)), _15528.zw * _17144);
            }
            else
            {
                _15550 = _15528;
            }
            _15549 = _15550;
        }
        else
        {
            _15549 = _15528;
        }
        float3 _6068 = (((_7403 * _15549.x) + (_7411 * _15549.y)) + (_7419 * _15549.z)) + (_7427 * _15549.w);
        float3 _16909;
        if (_4753 && (_15564 > 0.0f))
        {
            uint _12934_dummy_parameter;
            float2 _12949 = r_motion_tp1.Load(int3(int2(floor(_4512 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _12934_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _15826;
            if (_6726)
            {
                float2 _12994 = clamp((((_14022 + (_12949 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _12997 = tan(_12994.x);
                _15826 = (float2(_12997 / cbFI_DeviceToViewDepth.z, (tan(_12994.y) * sqrt(1.0f + (_12997 * _12997))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15826 = _14022 + (_12949 * cbFI_Timestep);
            }
            float2 _15827;
            if (_6726)
            {
                float2 _13073 = clamp((((_14022 + (_12949 * _4727)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13076 = tan(_13073.x);
                _15827 = (float2(_13076 / cbFI_DeviceToViewDepth.z, (tan(_13073.y) * sqrt(1.0f + (_13076 * _13076))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15827 = _14022 + (_12949 * _4727);
            }
            _16909 = lerp(_6068, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _15826, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _15827, 0.0f).xyz, cbFI_Timestep.xxx), _15564.xxx);
        }
        else
        {
            _16909 = _6068;
        }
        float3 _16908;
        if (_15834)
        {
            float3 _13118 = r_current_interpolation_source.Load(int3(_4051, 0)).xyz;
            float3 _16910;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _9800)
            {
                uint _13125_dummy_parameter;
                float _15957;
                _15957 = r_depth_tm1.Load(int3(int2(floor(_14045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13125_dummy_parameter))))), 0)).x;
                float _6149;
                for (int _15956 = 0; _15956 < 24; _15957 = _6149, _15956++)
                {
                    float _6121 = float(_15956 & 7) * 0.785398185253143310546875f;
                    int _6123 = _15956 >> 3;
                    int _16960;
                    if (_6123 == 0)
                    {
                        _16960 = 16;
                    }
                    else
                    {
                        _16960 = (_6123 == 1) ? 48 : 96;
                    }
                    uint _13145_dummy_parameter;
                    _6149 = max(_15957, r_depth_tm1.Load(int3(int2(floor(clamp(_14045 + ((cbFI_MvDepthLaneSizeRcp * float(_16960)) * float2(cos(_6121), sin(_6121))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13145_dummy_parameter))))), 0)).x);
                }
                float2 _15958;
                do
                {
                    float _13167 = 1.0f - _14045.y;
                    float4 _13178 = mul(float4((float2(_14045.x, _13167) * 2.0f) - 1.0f.xx, _15957, 1.0f), cbFI_MotionTM1ToTM2);
                    float _13180 = _13178.w;
                    if (!(_13180 > 9.9999999747524270787835121154785e-07f))
                    {
                        _15958 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13193 = ((_13178.xy / _13180.xx) + 1.0f.xx) * 0.5f;
                    _15958 = float2(_13193.x - _14045.x, _13167 - _13193.y);
                    break;
                } while(false);
                float2 _6160 = _14045 + _15958;
                bool _13211 = all(bool2(_6160.x > 0.0f.xx.x, _6160.y > 0.0f.xx.y));
                bool _13217;
                if (_13211)
                {
                    _13217 = all(bool2(_6160.x < 1.0f.xx.x, _6160.y < 1.0f.xx.y));
                }
                else
                {
                    _13217 = _13211;
                }
                float3 _16911;
                if (_13217)
                {
                    float _6166 = abs(cbFI_DeviceToViewDepth.y / (_15957 - cbFI_DeviceToViewDepth.x));
                    uint _13237_dummy_parameter;
                    int2 _13237 = int2(spvTextureSize(r_depth_m2, uint(0), _13237_dummy_parameter));
                    float _6170 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6160 * float2(_13237))), int2(0, 0), _13237 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _16916;
                    if (abs(_6170 - _6166) <= (0.20000000298023223876953125f * max(_6170, _6166)))
                    {
                        uint _13271_dummy_parameter;
                        int2 _13271 = int2(spvTextureSize(r_colour_m2, uint(0), _13271_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13294;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _13294);
                        }
                        _16916 = r_colour_m2.Load(int3(clamp(int2(floor(_6160 * float2(_13271))), int2(0, 0), _13271 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13304;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13304);
                        }
                        _16916 = _13118;
                    }
                    _16911 = _16916;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13314;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13314);
                    }
                    _16911 = _13118;
                }
                _16910 = _16911;
            }
            else
            {
                _16910 = _13118;
            }
            _16908 = _16910;
        }
        else
        {
            _16908 = _16909;
        }
        uint _6198 = cbFI_pad0 & 255u;
        bool _16785;
        float3 _16907;
        if (_6198 != 0u)
        {
            float3 _6203 = r_present_backbuffer.Load(int3(_4051, 0)).xyz;
            float3 _6207 = r_current_interpolation_source.Load(int3(_4051, 0)).xyz;
            float3 _6211 = abs(_6203 - _6207);
            float3 _15961;
            if (_6198 == 2u)
            {
                _15961 = (abs(_6207) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _15961 = 0.000244140625f.xxx;
            }
            bool _6227 = any(bool3(_6211.x > _15961.x, _6211.y > _15961.y, _6211.z > _15961.z));
            bool3 _17145 = _6227.xxx;
            _16907 = float3(_17145.x ? _6203.x : _16908.x, _17145.y ? _6203.y : _16908.y, _17145.z ? _6203.z : _16908.z);
            _16785 = _6227;
        }
        else
        {
            _16907 = _16908;
            _16785 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _13329;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _13329);
        }
        float3 _16890;
        if (_5885 == 1u)
        {
            _16890 = lerp(_7403, _7411, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _16891;
            if (_5885 == 2u)
            {
                _16891 = lerp(_7419, _7427, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _16892;
                if (_5885 == 3u)
                {
                    _16892 = float(_16785).xxx;
                }
                else
                {
                    float3 _16893;
                    if (_5885 == 4u)
                    {
                        _16893 = float3(((_14043 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _16894;
                        if (_5885 == 5u)
                        {
                            _16894 = float3(((_6698 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _16895;
                            if (_5885 == 6u)
                            {
                                _16895 = float3(_15549.xy, _15549.z + _15549.w);
                            }
                            else
                            {
                                float3 _16896;
                                if (_5885 == 7u)
                                {
                                    _16896 = r_current_interpolation_source.Load(int3(_4051, 0)).xyz;
                                }
                                else
                                {
                                    float3 _16897;
                                    if (_5885 == 8u)
                                    {
                                        _16897 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4512, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _16898;
                                        if (_5889)
                                        {
                                            uint _13351_dummy_parameter;
                                            uint _13383_dummy_parameter;
                                            _16898 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4512 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13351_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4512 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13383_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _16899;
                                            if (_5892)
                                            {
                                                _16899 = _7419;
                                            }
                                            else
                                            {
                                                float3 _16900;
                                                if (_5885 == 20u)
                                                {
                                                    _16900 = _7403;
                                                }
                                                else
                                                {
                                                    float3 _16901;
                                                    if (_5885 == 21u)
                                                    {
                                                        _16901 = _7411;
                                                    }
                                                    else
                                                    {
                                                        float3 _16902;
                                                        if (_5885 == 22u)
                                                        {
                                                            _16902 = _7427;
                                                        }
                                                        else
                                                        {
                                                            float3 _16903;
                                                            if (_5885 == 18u)
                                                            {
                                                                _16903 = _16433;
                                                            }
                                                            else
                                                            {
                                                                float3 _16904;
                                                                if (_5885 == 19u)
                                                                {
                                                                    _16904 = _16197;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _17147 = (_5885 == 23u).xxx;
                                                                    _16904 = float3(_17147.x ? _15967.x : _16907.x, _17147.y ? _15967.y : _16907.y, _17147.z ? _15967.z : _16907.z);
                                                                }
                                                                _16903 = _16904;
                                                            }
                                                            _16902 = _16903;
                                                        }
                                                        _16901 = _16902;
                                                    }
                                                    _16900 = _16901;
                                                }
                                                _16899 = _16900;
                                            }
                                            _16898 = _16899;
                                        }
                                        _16897 = _16898;
                                    }
                                    _16896 = _16897;
                                }
                                _16895 = _16896;
                            }
                            _16894 = _16895;
                        }
                        _16893 = _16894;
                    }
                    _16892 = _16893;
                }
                _16891 = _16892;
            }
            _16890 = _16891;
        }
        float3 _16889;
        if ((_5885 >= 9u) && (_5885 <= 11u))
        {
            uint _6391 = 64u + uint((_14266.y * cbFI_MvDepthLaneSize.x) + _14266.x);
            uint _6395 = rw_nfru_diagnostics.Load<uint>(_6391 * 4 + 0) & 15u;
            float3 _16921;
            if (_5885 == 10u)
            {
                float3 _16888;
                if ((rw_nfru_diagnostics.Load<uint>(_6391 * 4 + 0) & 32u) != 0u)
                {
                    _16888 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _16887;
                    if ((rw_nfru_diagnostics.Load<uint>(_6391 * 4 + 0) & 16u) != 0u)
                    {
                        _16887 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6416 = ((rw_nfru_diagnostics.Load<uint>(_6391 * 4 + 0) & 64u) != 0u).xxx;
                        _16887 = float3(_6416.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6416.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6416.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _16888 = _16887;
                }
                _16921 = _16888;
            }
            else
            {
                float3 _16922;
                if (_5885 == 11u)
                {
                    uint _6429 = (rw_nfru_diagnostics.Load<uint>(_6391 * 4 + 0) >> 8u) & 15u;
                    uint _6432 = (rw_nfru_diagnostics.Load<uint>(_6391 * 4 + 0) >> 12u) & 15u;
                    float3 _16880;
                    if ((_6395 == 2u) || (_6395 == 3u))
                    {
                        _16880 = _3764[_6395];
                    }
                    else
                    {
                        bool _6444 = _6429 == 3u;
                        bool _6446 = _6432 == 3u;
                        float3 _16881;
                        if (_6444 && _6446)
                        {
                            _16881 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _16882;
                            if (_6444)
                            {
                                _16882 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _16883;
                                if (_6446)
                                {
                                    _16883 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _16884;
                                    if ((_6429 == 4u) || (_6432 == 4u))
                                    {
                                        _16884 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _16885;
                                        if ((_6429 == 1u) || (_6432 == 1u))
                                        {
                                            _16885 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _17149 = (_6395 == 1u).xxx;
                                            _16885 = float3(_17149.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _17149.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _17149.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _16884 = _16885;
                                    }
                                    _16883 = _16884;
                                }
                                _16882 = _16883;
                            }
                            _16881 = _16882;
                        }
                        _16880 = _16881;
                    }
                    _16922 = _16880;
                }
                else
                {
                    _16922 = _3764[min(_6395, 7u)];
                }
                _16921 = _16922;
            }
            _16889 = _16921;
        }
        else
        {
            _16889 = _16890;
        }
        float4 _16925;
        if ((_5885 >= 14u) && (_5885 <= 16u))
        {
            float2 _16923;
            if (_5885 == 14u)
            {
                uint _6502_dummy_parameter;
                uint _6508_dummy_parameter;
                _16923 = r_flow_tm1.Load(int3(clamp(int2(floor(_4512 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6502_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6508_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _16924;
                if (_5885 == 16u)
                {
                    uint _13434 = r_warped_flow_qdata_tm1.Load(int3(_4528, 0)).x & 2147483647u;
                    uint _13466 = uint(max((int((_13434 >> 16u) & 15u) - 6), 0));
                    _16924 = ((float2(float((1 - (2 * int((_13434 >> 15u) & 1u))) * int(((_13434 >> uint(7)) & 127u) << _13466)), float((1 - (2 * int((_13434 >> 14u) & 1u))) * int((_13434 & 127u) << _13466))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _16924 = _6698 * float2(cbFI_DisplaySize);
                }
                _16923 = _16924;
            }
            uint2 _6541 = uint2(clamp(round(_16923 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6543 = _6541.x;
            uint _6550 = _6541.y;
            _16925 = float4(float(_6543 & 255u), float((_6543 >> 8u) | ((_6550 & 15u) << 4u)), float(_6550 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _16926;
            if (_5885 == 17u)
            {
                _16926 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4528, 0)).x != 0u), _4972, 0.0f, 1.0f);
            }
            else
            {
                _16926 = float4(_16889, 1.0f);
            }
            _16925 = _16926;
        }
        rw_output[_4051] = _16925.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6594 = ((uint(_4051.y) * uint(cbFI_DisplaySize.x)) + uint(_4051.x)) * 6u;
            uint _13512 = spvPackHalf2x16(clamp(_7402.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6594 * 4 + 0, (((_13512 & 32767u) >> 4u) | ((((_13512 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7402.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13547 = spvPackHalf2x16(clamp(_7410.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6594 + 1u) * 4 + 0, (((_13547 & 32767u) >> 4u) | ((((_13547 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7410.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13582 = spvPackHalf2x16(clamp(_7418.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6594 + 2u) * 4 + 0, (((_13582 & 32767u) >> 4u) | ((((_13582 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7418.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13617 = spvPackHalf2x16(clamp(_7426.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6594 + 3u) * 4 + 0, (((_13617 & 32767u) >> 4u) | ((((_13617 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7426.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _13644 = r_current_interpolation_source.Load(int3(_4051, 0));
            uint _13658 = spvPackHalf2x16(clamp(_13644.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6594 + 4u) * 4 + 0, (((_13658 & 32767u) >> 4u) | ((((_13658 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_13644.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _16959;
            if (_16785 || (_5885 != 0u))
            {
                _16959 = 4294967295u;
            }
            else
            {
                uint _13693 = spvPackHalf2x16(clamp(_16925.xy, 0.0f.xx, 65000.0f.xx));
                _16959 = (((_13693 & 32767u) >> 4u) | ((((_13693 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_16925.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6594 + 5u) * 4 + 0, _16959);
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
