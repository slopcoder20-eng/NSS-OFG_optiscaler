static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1098[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1107[5] = { 2, 4, 7, 11, 16 };
static const float3 _3694[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3998 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3998.x >= cbFI_DisplaySize.x, _3998.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3998] = float4(r_present_backbuffer.Load(int3(_3998, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3998] = float4(r_current_interpolation_source.Load(int3(_3998, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4457 = (float2(_3998) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4459 = float2(cbFI_MvDepthLaneSize);
        int2 _4468 = int2(floor(_4457 * _4459));
        int2 _4473 = int2(floor(_4457 * float2(cbFI_FlowLaneSize)));
        float4 _6661 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4457 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6667 = r_warped_filled_flow_tm1.Load(int3(_4473, 0)).xy;
        float2 _6673 = r_warped_filled_motion_tp1.Load(int3(_4468, 0)).xy;
        bool _6695 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _12565;
        if (_6695)
        {
            float _6708 = ((2.0f * _4457.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _12565 = float2(atan(_6708) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4457.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6708 * _6708))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _12565 = _4457;
        }
        bool _4494 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _12586;
        bool _12656;
        int2 _12705;
        float3 _14566;
        if (_4494)
        {
            float _12567;
            float _12569;
            _12569 = 2.0f;
            _12567 = -1.0f;
            uint _4067[9];
            float _15066;
            float _15069;
            for (int _12566 = 0; _12566 < 9; _12569 = _15069, _12567 = _15066, _12566++)
            {
                _4067[_12566] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4468 + int2((_12566 % 3) - 1, (_12566 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4067[_12566] != 0u)
                {
                    float _15061;
                    if (_4067[_12566] == 0u)
                    {
                        _15061 = -1.0f;
                    }
                    else
                    {
                        _15061 = float((_4067[_12566] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _15069 = min(_12569, _15061);
                    _15066 = max(_12567, _15061);
                }
                else
                {
                    _15069 = _12569;
                    _15066 = _12567;
                }
            }
            float _4540 = float(_12567 >= 0.0f);
            float3 _12268 = 0.0f.xxx;
            _12268.y = _4540;
            float2 _12587;
            bool _12657;
            int2 _12706;
            float3 _14567;
            if ((_12567 - _12569) > 0.0199999995529651641845703125f)
            {
                float _12575;
                int2 _12576;
                float2 _12577;
                int2 _12579;
                float2 _12585;
                _12585 = _6673;
                _12579 = _4468;
                _12577 = _6673;
                _12576 = _4468;
                _12575 = -1.0f;
                float _15074;
                int2 _15078;
                float2 _15089;
                int2 _15100;
                float2 _15133;
                float _15180;
                int _12574 = 0;
                float _15042 = 1000000000.0f;
                for (; _12574 < 9; _15042 = _15180, _12585 = _15133, _12579 = _15100, _12577 = _15089, _12576 = _15078, _12575 = _15074, _12574++)
                {
                    if (_4067[_12574] == 0u)
                    {
                        _15180 = _15042;
                        _15133 = _12585;
                        _15100 = _12579;
                        _15089 = _12577;
                        _15078 = _12576;
                        _15074 = _12575;
                        continue;
                    }
                    int2 _4575 = clamp(_4468 + int2((_12574 % 3) - 1, (_12574 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6783 = _4067[_12574] & 2147483647u;
                    uint _6815 = uint(max((int((_6783 >> 16u) & 15u) - 6), 0));
                    float2 _4581 = (float2(float((1 - (2 * int((_6783 >> 15u) & 1u))) * int(((_6783 >> uint(7)) & 127u) << _6815)), float((1 - (2 * int((_6783 >> 14u) & 1u))) * int((_6783 & 127u) << _6815))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _15028;
                    if (_4067[_12574] == 0u)
                    {
                        _15028 = -1.0f;
                    }
                    else
                    {
                        _15028 = float((_4067[_12574] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4586 = _15028 - 0.100000001490116119384765625f;
                    float2 _15029;
                    if (_6695)
                    {
                        float2 _6892 = clamp((((_12565 + (_4581 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6895 = tan(_6892.x);
                        _15029 = (float2(_6895 / cbFI_DeviceToViewDepth.z, (tan(_6892.y) * sqrt(1.0f + (_6895 * _6895))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _15029 = _12565 + (_4581 * cbFI_Timestep);
                    }
                    float _4593 = cbFI_Timestep - 1.0f;
                    float2 _15030;
                    if (_6695)
                    {
                        float2 _6963 = clamp((((_12565 + (_4581 * _4593)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6966 = tan(_6963.x);
                        _15030 = (float2(_6966 / cbFI_DeviceToViewDepth.z, (tan(_6963.y) * sqrt(1.0f + (_6966 * _6966))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _15030 = _12565 + (_4581 * _4593);
                    }
                    bool _6999 = all(bool2(_15029.x > 0.0f.xx.x, _15029.y > 0.0f.xx.y));
                    bool _7005;
                    if (_6999)
                    {
                        _7005 = all(bool2(_15029.x < 1.0f.xx.x, _15029.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7005 = _6999;
                    }
                    float _15033;
                    if (_7005)
                    {
                        uint _7012_dummy_parameter;
                        _15033 = max((_4586 - (log((r_depth_tm1.Load(int3(int2(floor(_15029 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7012_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _15033 = 0.0f;
                    }
                    bool _7042 = all(bool2(_15030.x > 0.0f.xx.x, _15030.y > 0.0f.xx.y));
                    bool _7048;
                    if (_7042)
                    {
                        _7048 = all(bool2(_15030.x < 1.0f.xx.x, _15030.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7048 = _7042;
                    }
                    float _15034;
                    if (_7048)
                    {
                        uint _7055_dummy_parameter;
                        _15034 = _15033 + max((_4586 - (log((r_depth_tp1.Load(int3(int2(floor(_15030 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7055_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _15034 = _15033;
                    }
                    float _15075;
                    int2 _15079;
                    float2 _15090;
                    int2 _15101;
                    float2 _15134;
                    float _15181;
                    if (_15034 == 0.0f)
                    {
                        bool _4628 = _4586 > _12575;
                        bool2 _15189 = _4628.xx;
                        _15181 = _15042;
                        _15134 = float2(_15189.x ? _4581.x : _12585.x, _15189.y ? _4581.y : _12585.y);
                        _15101 = int2(_15189.x ? _4575.x : _12579.x, _15189.y ? _4575.y : _12579.y);
                        _15090 = _12577;
                        _15079 = _12576;
                        _15075 = _4628 ? _4586 : _12575;
                    }
                    else
                    {
                        bool _4637 = _15034 < _15042;
                        bool2 _15185 = _4637.xx;
                        _15181 = _4637 ? _15034 : _15042;
                        _15134 = _12585;
                        _15101 = _12579;
                        _15090 = float2(_15185.x ? _4581.x : _12577.x, _15185.y ? _4581.y : _12577.y);
                        _15079 = int2(_15185.x ? _4575.x : _12576.x, _15185.y ? _4575.y : _12576.y);
                        _15075 = _12575;
                    }
                    _15180 = _15181;
                    _15133 = _15134;
                    _15100 = _15101;
                    _15089 = _15090;
                    _15078 = _15079;
                    _15074 = _15075;
                }
                bool _4649 = _12575 < 0.0f;
                bool2 _15195 = _4649.xx;
                int2 _15198 = int2(_15195.x ? _12576.x : _12579.x, _15195.y ? _12576.y : _12579.y);
                _14567 = float3(1.0f, _4540, float(any(bool2(_15198.x != _4468.x, _15198.y != _4468.y))));
                _12706 = _15198;
                _12657 = _4649 ? false : true;
                _12587 = float2(_15195.x ? _12577.x : _12585.x, _15195.y ? _12577.y : _12585.y);
            }
            else
            {
                _14567 = _12268;
                _12706 = _4468;
                _12657 = false;
                _12587 = _6673;
            }
            _14566 = _14567;
            _12705 = _12706;
            _12656 = _12657;
            _12586 = _12587;
        }
        else
        {
            _14566 = 0.0f.xxx;
            _12705 = _4468;
            _12656 = false;
            _12586 = _6673;
        }
        float2 _12588;
        if (_6695)
        {
            float2 _7120 = clamp((((_12565 + (_12586 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7123 = tan(_7120.x);
            _12588 = (float2(_7123 / cbFI_DeviceToViewDepth.z, (tan(_7120.y) * sqrt(1.0f + (_7123 * _7123))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12588 = _12565 + (_12586 * cbFI_Timestep);
        }
        float _4672 = cbFI_Timestep - 1.0f;
        float2 _12590;
        if (_6695)
        {
            float2 _7191 = clamp((((_12565 + (_12586 * _4672)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7194 = tan(_7191.x);
            _12590 = (float2(_7194 / cbFI_DeviceToViewDepth.z, (tan(_7191.y) * sqrt(1.0f + (_7194 * _7194))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12590 = _12565 + (_12586 * _4672);
        }
        float _4677 = -cbFI_Timestep;
        float2 _12591;
        if (_6695)
        {
            float2 _7262 = clamp((((_12565 + (_6667 * _4677)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7265 = tan(_7262.x);
            _12591 = (float2(_7265 / cbFI_DeviceToViewDepth.z, (tan(_7262.y) * sqrt(1.0f + (_7265 * _7265))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12591 = _12565 + (_6667 * _4677);
        }
        float _4682 = 1.0f - cbFI_Timestep;
        float2 _12592;
        if (_6695)
        {
            float2 _7333 = clamp((((_12565 + (_6667 * _4682)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7336 = tan(_7333.x);
            _12592 = (float2(_7336 / cbFI_DeviceToViewDepth.z, (tan(_7333.y) * sqrt(1.0f + (_7336 * _7336))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12592 = _12565 + (_6667 * _4682);
        }
        float4 _7371 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _12588, 0.0f);
        float3 _7372 = _7371.xyz;
        float4 _7379 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _12590, 0.0f);
        float3 _7380 = _7379.xyz;
        float4 _7387 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _12591, 0.0f);
        float3 _7388 = _7387.xyz;
        float4 _7395 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _12592, 0.0f);
        float3 _7396 = _7395.xyz;
        float4 _7410 = exp(_6661 - max(max(max(_6661.x, _6661.y), _6661.z), _6661.w).xxxx);
        float4 _7417 = _7410 / (dot(_7410, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4698 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _12695;
        float _13801;
        if (_4698)
        {
            float2 _4704 = 0.5f.xx / _4459;
            float _4707 = _4704.x;
            float _4708 = -_4707;
            float _4710 = _4704.y;
            float _4711 = -_4710;
            float2 _4713 = _4457 + float2(_4708, _4711);
            float2 _4715 = float2(cbFI_DisplaySize);
            bool _12604;
            do
            {
                bool _7497 = all(bool2(_4713.x > 0.0f.xx.x, _4713.y > 0.0f.xx.y));
                bool _7503;
                if (_7497)
                {
                    _7503 = all(bool2(_4713.x < 1.0f.xx.x, _4713.y < 1.0f.xx.y));
                }
                else
                {
                    _7503 = _7497;
                }
                if (!_7503)
                {
                    _12604 = false;
                    break;
                }
                uint _7510_dummy_parameter;
                float2 _12603;
                do
                {
                    float _7533 = _4713.x;
                    float _7536 = 1.0f - _4713.y;
                    float4 _7547 = mul(float4((float2(_7533, _7536) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4713 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7510_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7549 = _7547.w;
                    if (!(_7549 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12603 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7562 = ((_7547.xy / _7549.xx) + 1.0f.xx) * 0.5f;
                    _12603 = float2(_7562.x - _7533, _7536 - _7562.y);
                    break;
                } while(false);
                float2 _7461 = abs(_12603);
                if (any(bool2(_7461.x > 100000.0f.xx.x, _7461.y > 100000.0f.xx.y)))
                {
                    _12604 = false;
                    break;
                }
                float _7469 = length(_12603 * _4715);
                uint _7582_dummy_parameter;
                bool _7483 = _7469 > ((8.0f * _4715.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7490;
                if (_7483)
                {
                    _7490 = length((r_motion_tp1.Load(int3(int2(floor(_4713 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7582_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4715) < (0.20000000298023223876953125f * _7469);
                }
                else
                {
                    _7490 = _7483;
                }
                _12604 = _7490;
                break;
            } while(false);
            float2 _4725 = _4457 + float2(_4707, _4711);
            bool _12606;
            do
            {
                bool _7668 = all(bool2(_4725.x > 0.0f.xx.x, _4725.y > 0.0f.xx.y));
                bool _7674;
                if (_7668)
                {
                    _7674 = all(bool2(_4725.x < 1.0f.xx.x, _4725.y < 1.0f.xx.y));
                }
                else
                {
                    _7674 = _7668;
                }
                if (!_7674)
                {
                    _12606 = false;
                    break;
                }
                uint _7681_dummy_parameter;
                float2 _12605;
                do
                {
                    float _7704 = _4725.x;
                    float _7707 = 1.0f - _4725.y;
                    float4 _7718 = mul(float4((float2(_7704, _7707) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4725 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7681_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7720 = _7718.w;
                    if (!(_7720 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12605 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7733 = ((_7718.xy / _7720.xx) + 1.0f.xx) * 0.5f;
                    _12605 = float2(_7733.x - _7704, _7707 - _7733.y);
                    break;
                } while(false);
                float2 _7632 = abs(_12605);
                if (any(bool2(_7632.x > 100000.0f.xx.x, _7632.y > 100000.0f.xx.y)))
                {
                    _12606 = false;
                    break;
                }
                float _7640 = length(_12605 * _4715);
                uint _7753_dummy_parameter;
                bool _7654 = _7640 > ((8.0f * _4715.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7661;
                if (_7654)
                {
                    _7661 = length((r_motion_tp1.Load(int3(int2(floor(_4725 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7753_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4715) < (0.20000000298023223876953125f * _7640);
                }
                else
                {
                    _7661 = _7654;
                }
                _12606 = _7661;
                break;
            } while(false);
            float2 _4738 = _4457 + float2(_4708, _4710);
            bool _12608;
            do
            {
                bool _7839 = all(bool2(_4738.x > 0.0f.xx.x, _4738.y > 0.0f.xx.y));
                bool _7845;
                if (_7839)
                {
                    _7845 = all(bool2(_4738.x < 1.0f.xx.x, _4738.y < 1.0f.xx.y));
                }
                else
                {
                    _7845 = _7839;
                }
                if (!_7845)
                {
                    _12608 = false;
                    break;
                }
                uint _7852_dummy_parameter;
                float2 _12607;
                do
                {
                    float _7875 = _4738.x;
                    float _7878 = 1.0f - _4738.y;
                    float4 _7889 = mul(float4((float2(_7875, _7878) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4738 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7852_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7891 = _7889.w;
                    if (!(_7891 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12607 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7904 = ((_7889.xy / _7891.xx) + 1.0f.xx) * 0.5f;
                    _12607 = float2(_7904.x - _7875, _7878 - _7904.y);
                    break;
                } while(false);
                float2 _7803 = abs(_12607);
                if (any(bool2(_7803.x > 100000.0f.xx.x, _7803.y > 100000.0f.xx.y)))
                {
                    _12608 = false;
                    break;
                }
                float _7811 = length(_12607 * _4715);
                uint _7924_dummy_parameter;
                bool _7825 = _7811 > ((8.0f * _4715.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7832;
                if (_7825)
                {
                    _7832 = length((r_motion_tp1.Load(int3(int2(floor(_4738 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7924_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4715) < (0.20000000298023223876953125f * _7811);
                }
                else
                {
                    _7832 = _7825;
                }
                _12608 = _7832;
                break;
            } while(false);
            float2 _4750 = _4457 + _4704;
            bool _12610;
            do
            {
                bool _8010 = all(bool2(_4750.x > 0.0f.xx.x, _4750.y > 0.0f.xx.y));
                bool _8016;
                if (_8010)
                {
                    _8016 = all(bool2(_4750.x < 1.0f.xx.x, _4750.y < 1.0f.xx.y));
                }
                else
                {
                    _8016 = _8010;
                }
                if (!_8016)
                {
                    _12610 = false;
                    break;
                }
                uint _8023_dummy_parameter;
                float2 _12609;
                do
                {
                    float _8046 = _4750.x;
                    float _8049 = 1.0f - _4750.y;
                    float4 _8060 = mul(float4((float2(_8046, _8049) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4750 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8023_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _8062 = _8060.w;
                    if (!(_8062 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12609 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8075 = ((_8060.xy / _8062.xx) + 1.0f.xx) * 0.5f;
                    _12609 = float2(_8075.x - _8046, _8049 - _8075.y);
                    break;
                } while(false);
                float2 _7974 = abs(_12609);
                if (any(bool2(_7974.x > 100000.0f.xx.x, _7974.y > 100000.0f.xx.y)))
                {
                    _12610 = false;
                    break;
                }
                float _7982 = length(_12609 * _4715);
                uint _8095_dummy_parameter;
                bool _7996 = _7982 > ((8.0f * _4715.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8003;
                if (_7996)
                {
                    _8003 = length((r_motion_tp1.Load(int3(int2(floor(_4750 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8095_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4715) < (0.20000000298023223876953125f * _7982);
                }
                else
                {
                    _8003 = _7996;
                }
                _12610 = _8003;
                break;
            } while(false);
            float _4756 = 0.25f * (((float(_12604) + float(_12606)) + float(_12608)) + float(_12610));
            float4 _12696;
            if (_4756 < 1.0f)
            {
                bool _12612;
                do
                {
                    bool _8181 = all(bool2(_12588.x > 0.0f.xx.x, _12588.y > 0.0f.xx.y));
                    bool _8187;
                    if (_8181)
                    {
                        _8187 = all(bool2(_12588.x < 1.0f.xx.x, _12588.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8187 = _8181;
                    }
                    if (!_8187)
                    {
                        _12612 = false;
                        break;
                    }
                    uint _8194_dummy_parameter;
                    float2 _12611;
                    do
                    {
                        float _8220 = 1.0f - _12588.y;
                        float4 _8231 = mul(float4((float2(_12588.x, _8220) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12588 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8194_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8233 = _8231.w;
                        if (!(_8233 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12611 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8246 = ((_8231.xy / _8233.xx) + 1.0f.xx) * 0.5f;
                        _12611 = float2(_8246.x - _12588.x, _8220 - _8246.y);
                        break;
                    } while(false);
                    float2 _8145 = abs(_12611);
                    if (any(bool2(_8145.x > 100000.0f.xx.x, _8145.y > 100000.0f.xx.y)))
                    {
                        _12612 = false;
                        break;
                    }
                    float _8153 = length(_12611 * _4715);
                    uint _8266_dummy_parameter;
                    bool _8167 = _8153 > ((8.0f * _4715.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8174;
                    if (_8167)
                    {
                        _8174 = length((r_motion_tp1.Load(int3(int2(floor(_12588 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8266_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4715) < (0.20000000298023223876953125f * _8153);
                    }
                    else
                    {
                        _8174 = _8167;
                    }
                    _12612 = _8174;
                    break;
                } while(false);
                bool _12614;
                do
                {
                    bool _8352 = all(bool2(_12590.x > 0.0f.xx.x, _12590.y > 0.0f.xx.y));
                    bool _8358;
                    if (_8352)
                    {
                        _8358 = all(bool2(_12590.x < 1.0f.xx.x, _12590.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8358 = _8352;
                    }
                    if (!_8358)
                    {
                        _12614 = false;
                        break;
                    }
                    uint _8365_dummy_parameter;
                    float2 _12613;
                    do
                    {
                        float _8391 = 1.0f - _12590.y;
                        float4 _8402 = mul(float4((float2(_12590.x, _8391) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12590 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8365_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8404 = _8402.w;
                        if (!(_8404 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12613 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8417 = ((_8402.xy / _8404.xx) + 1.0f.xx) * 0.5f;
                        _12613 = float2(_8417.x - _12590.x, _8391 - _8417.y);
                        break;
                    } while(false);
                    float2 _8316 = abs(_12613);
                    if (any(bool2(_8316.x > 100000.0f.xx.x, _8316.y > 100000.0f.xx.y)))
                    {
                        _12614 = false;
                        break;
                    }
                    float _8324 = length(_12613 * _4715);
                    uint _8437_dummy_parameter;
                    bool _8338 = _8324 > ((8.0f * _4715.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8345;
                    if (_8338)
                    {
                        _8345 = length((r_motion_tp1.Load(int3(int2(floor(_12590 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8437_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4715) < (0.20000000298023223876953125f * _8324);
                    }
                    else
                    {
                        _8345 = _8338;
                    }
                    _12614 = _8345;
                    break;
                } while(false);
                bool _12616;
                do
                {
                    bool _8523 = all(bool2(_12591.x > 0.0f.xx.x, _12591.y > 0.0f.xx.y));
                    bool _8529;
                    if (_8523)
                    {
                        _8529 = all(bool2(_12591.x < 1.0f.xx.x, _12591.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8529 = _8523;
                    }
                    if (!_8529)
                    {
                        _12616 = false;
                        break;
                    }
                    uint _8536_dummy_parameter;
                    float2 _12615;
                    do
                    {
                        float _8562 = 1.0f - _12591.y;
                        float4 _8573 = mul(float4((float2(_12591.x, _8562) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12591 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8536_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8575 = _8573.w;
                        if (!(_8575 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12615 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8588 = ((_8573.xy / _8575.xx) + 1.0f.xx) * 0.5f;
                        _12615 = float2(_8588.x - _12591.x, _8562 - _8588.y);
                        break;
                    } while(false);
                    float2 _8487 = abs(_12615);
                    if (any(bool2(_8487.x > 100000.0f.xx.x, _8487.y > 100000.0f.xx.y)))
                    {
                        _12616 = false;
                        break;
                    }
                    float _8495 = length(_12615 * _4715);
                    uint _8608_dummy_parameter;
                    bool _8509 = _8495 > ((8.0f * _4715.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8516;
                    if (_8509)
                    {
                        _8516 = length((r_motion_tp1.Load(int3(int2(floor(_12591 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8608_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4715) < (0.20000000298023223876953125f * _8495);
                    }
                    else
                    {
                        _8516 = _8509;
                    }
                    _12616 = _8516;
                    break;
                } while(false);
                bool _12618;
                do
                {
                    bool _8694 = all(bool2(_12592.x > 0.0f.xx.x, _12592.y > 0.0f.xx.y));
                    bool _8700;
                    if (_8694)
                    {
                        _8700 = all(bool2(_12592.x < 1.0f.xx.x, _12592.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8700 = _8694;
                    }
                    if (!_8700)
                    {
                        _12618 = false;
                        break;
                    }
                    uint _8707_dummy_parameter;
                    float2 _12617;
                    do
                    {
                        float _8733 = 1.0f - _12592.y;
                        float4 _8744 = mul(float4((float2(_12592.x, _8733) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12592 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8707_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8746 = _8744.w;
                        if (!(_8746 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12617 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8759 = ((_8744.xy / _8746.xx) + 1.0f.xx) * 0.5f;
                        _12617 = float2(_8759.x - _12592.x, _8733 - _8759.y);
                        break;
                    } while(false);
                    float2 _8658 = abs(_12617);
                    if (any(bool2(_8658.x > 100000.0f.xx.x, _8658.y > 100000.0f.xx.y)))
                    {
                        _12618 = false;
                        break;
                    }
                    float _8666 = length(_12617 * _4715);
                    uint _8779_dummy_parameter;
                    bool _8680 = _8666 > ((8.0f * _4715.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8687;
                    if (_8680)
                    {
                        _8687 = length((r_motion_tp1.Load(int3(int2(floor(_12592 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8779_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4715) < (0.20000000298023223876953125f * _8666);
                    }
                    else
                    {
                        _8687 = _8680;
                    }
                    _12618 = _8687;
                    break;
                } while(false);
                float4 _4783 = _7417 * float4(_12612 ? 0.0f : 1.0f, _12614 ? 0.0f : 1.0f, _12616 ? 0.0f : 1.0f, _12618 ? 0.0f : 1.0f);
                float _4785 = dot(_4783, 1.0f.xxxx);
                float4 _12697;
                if (_4785 > 0.001000000047497451305389404296875f)
                {
                    _12697 = _4783 / _4785.xxxx;
                }
                else
                {
                    _12697 = _7417;
                }
                _12696 = _12697;
            }
            else
            {
                _12696 = _7417;
            }
            _13801 = _4756;
            _12695 = _12696;
        }
        else
        {
            _13801 = 0.0f;
            _12695 = _7417;
        }
        bool _4802 = _4494 && (!_12656);
        bool _4811;
        if (_4802)
        {
            _4811 = (_12695.z + _12695.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4811 = _4802;
        }
        bool _4822;
        if (_4811)
        {
            _4822 = length((_12591 - _12588) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4822 = _4811;
        }
        bool _12752;
        if (_4822)
        {
            uint4 _8808 = r_warped_motion_qdata_tp1.Load(int3(_12705, 0));
            uint _8809 = _8808.x;
            bool _12755;
            if (_8809 != 0u)
            {
                float _12741;
                if (_8809 == 0u)
                {
                    _12741 = -1.0f;
                }
                else
                {
                    _12741 = float((_8809 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4832 = _12741 - 0.12000000476837158203125f;
                bool _8828 = all(bool2(_12591.x > 0.0f.xx.x, _12591.y > 0.0f.xx.y));
                bool _8834;
                if (_8828)
                {
                    _8834 = all(bool2(_12591.x < 1.0f.xx.x, _12591.y < 1.0f.xx.y));
                }
                else
                {
                    _8834 = _8828;
                }
                bool _4842;
                if (_8834)
                {
                    uint _8841_dummy_parameter;
                    _4842 = (log((r_depth_tm1.Load(int3(int2(floor(_12591 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8841_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4832;
                }
                else
                {
                    _4842 = _8834;
                }
                bool _4856;
                if (!_4842)
                {
                    bool _8871 = all(bool2(_12592.x > 0.0f.xx.x, _12592.y > 0.0f.xx.y));
                    bool _8877;
                    if (_8871)
                    {
                        _8877 = all(bool2(_12592.x < 1.0f.xx.x, _12592.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8877 = _8871;
                    }
                    bool _4854;
                    if (_8877)
                    {
                        uint _8884_dummy_parameter;
                        _4854 = (log((r_depth_tp1.Load(int3(int2(floor(_12592 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8884_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4832;
                    }
                    else
                    {
                        _4854 = _8877;
                    }
                    _4856 = _4854;
                }
                else
                {
                    _4856 = _4842;
                }
                _12755 = _4856;
            }
            else
            {
                _12755 = false;
            }
            _12752 = _12755;
        }
        else
        {
            _12752 = false;
        }
        bool _4861 = _12656 || _12752;
        bool _4866;
        if (_4861)
        {
            bool _8914 = all(bool2(_12588.x > 0.0f.xx.x, _12588.y > 0.0f.xx.y));
            bool _8920;
            if (_8914)
            {
                _8920 = all(bool2(_12588.x < 1.0f.xx.x, _12588.y < 1.0f.xx.y));
            }
            else
            {
                _8920 = _8914;
            }
            _4866 = _8920;
        }
        else
        {
            _4866 = _4861;
        }
        bool _4871;
        if (_4866)
        {
            bool _8925 = all(bool2(_12590.x > 0.0f.xx.x, _12590.y > 0.0f.xx.y));
            bool _8931;
            if (_8925)
            {
                _8931 = all(bool2(_12590.x < 1.0f.xx.x, _12590.y < 1.0f.xx.y));
            }
            else
            {
                _8931 = _8925;
            }
            _4871 = _8931;
        }
        else
        {
            _4871 = _4866;
        }
        float4 _12849;
        if (_4871)
        {
            float _4877 = _12695.x + _12695.y;
            float _4882 = _12695.z + _12695.w;
            float _12770;
            if (_4877 > 0.001000000047497451305389404296875f)
            {
                _12770 = _12695.x / _4877;
            }
            else
            {
                _12770 = _4682;
            }
            _12849 = float4(_12695.x + (_4882 * _12770), _12695.y + (_4882 * (1.0f - _12770)), 0.0f, 0.0f);
        }
        else
        {
            _12849 = _12695;
        }
        bool _8959 = (cbFI_pad0 & 1024u) != 0u;
        bool _8935 = !_8959;
        bool _8936 = !_8935;
        bool _8953;
        if (_8936)
        {
            _8953 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_12705.y * cbFI_MvDepthLaneSize.x) + _12705.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _8953 = _8935;
        }
        bool _8985;
        if (_8936)
        {
            _8985 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4473.y * cbFI_FlowLaneSize.x) + _4473.x)) * 4 + 0) != 0u;
        }
        else
        {
            _8985 = _8935;
        }
        float _4917 = float(_8985);
        bool _12862;
        float4 _12893;
        float3 _14354;
        if (_8959)
        {
            bool _4927;
            if (_8953)
            {
                _4927 = all(bool2(_12588.x > 0.0f.xx.x, _12588.y > 0.0f.xx.y));
            }
            else
            {
                _4927 = _8953;
            }
            bool _4933;
            if (_4927)
            {
                _4933 = all(bool2(_12588.x < 1.0f.xx.x, _12588.y < 1.0f.xx.y));
            }
            else
            {
                _4933 = _4927;
            }
            bool _4940;
            if (_8953)
            {
                _4940 = all(bool2(_12590.x > 0.0f.xx.x, _12590.y > 0.0f.xx.y));
            }
            else
            {
                _4940 = _8953;
            }
            bool _4946;
            if (_4940)
            {
                _4946 = all(bool2(_12590.x < 1.0f.xx.x, _12590.y < 1.0f.xx.y));
            }
            else
            {
                _4946 = _4940;
            }
            bool _4953;
            if (_8985)
            {
                _4953 = all(bool2(_12591.x > 0.0f.xx.x, _12591.y > 0.0f.xx.y));
            }
            else
            {
                _4953 = _8985;
            }
            bool _4959;
            if (_4953)
            {
                _4959 = all(bool2(_12591.x < 1.0f.xx.x, _12591.y < 1.0f.xx.y));
            }
            else
            {
                _4959 = _4953;
            }
            bool _4966;
            if (_8985)
            {
                _4966 = all(bool2(_12592.x > 0.0f.xx.x, _12592.y > 0.0f.xx.y));
            }
            else
            {
                _4966 = _8985;
            }
            bool _4972;
            if (_4966)
            {
                _4972 = all(bool2(_12592.x < 1.0f.xx.x, _12592.y < 1.0f.xx.y));
            }
            else
            {
                _4972 = _4966;
            }
            bool _4974 = !_8953;
            if (_4974)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9027;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _9027);
                }
            }
            bool _4979 = !_8985;
            if (_4979)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9037;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _9037);
                }
            }
            if (_8953 && _4979)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9047;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _9047);
                }
            }
            if (_4974 && _8985)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9057;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _9057);
                }
            }
            float _4998 = float(_4933);
            float _5000 = float(_4946);
            bool _5003 = _4959 && _4972;
            float _12804;
            if (_5003)
            {
                _12804 = 1.0f;
            }
            else
            {
                _12804 = (_4959 || _4972) ? 0.5f : 0.0f;
            }
            bool _12809;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4933)) && (!_4946))
            {
                bool _5033;
                if (_5003)
                {
                    float _12807;
                    do
                    {
                        bool _9141 = all(bool2(_12591.x > 0.0f.xx.x, _12591.y > 0.0f.xx.y));
                        bool _9147;
                        if (_9141)
                        {
                            _9147 = all(bool2(_12591.x < 1.0f.xx.x, _12591.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _9147 = _9141;
                        }
                        bool _9078 = !_9147;
                        bool _9085;
                        if (!_9078)
                        {
                            bool _9152 = all(bool2(_12592.x > 0.0f.xx.x, _12592.y > 0.0f.xx.y));
                            bool _9158;
                            if (_9152)
                            {
                                _9158 = all(bool2(_12592.x < 1.0f.xx.x, _12592.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _9158 = _9152;
                            }
                            _9085 = !_9158;
                        }
                        else
                        {
                            _9085 = _9078;
                        }
                        if (_9085)
                        {
                            _12807 = 0.0f;
                            break;
                        }
                        uint _9165_dummy_parameter;
                        uint _9181_dummy_parameter;
                        float4 _9106 = mul(float4((float2(_12591.x, 1.0f - _12591.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12591 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9165_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _9108 = _9106.w;
                        if (abs(_9108) < 9.9999999747524270787835121154785e-07f)
                        {
                            _12807 = 0.0f;
                            break;
                        }
                        float _9119 = abs(cbFI_DeviceToViewDepth.y / ((_9106.z / _9108) - cbFI_DeviceToViewDepth.x));
                        float _9122 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12592 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9181_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _12807 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9119 - _9122) / max(max(_9119, _9122), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5033 = _12807 >= 0.5f;
                }
                else
                {
                    _5033 = _5003;
                }
                bool _5041;
                if (_5033)
                {
                    _5041 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5041 = _5033;
                }
                bool _12810;
                if (_5041)
                {
                    uint _9231_dummy_parameter;
                    float2 _12808;
                    do
                    {
                        float _9257 = 1.0f - _12591.y;
                        float4 _9268 = mul(float4((float2(_12591.x, _9257) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12591 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9231_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _9270 = _9268.w;
                        if (!(_9270 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12808 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9283 = ((_9268.xy / _9270.xx) + 1.0f.xx) * 0.5f;
                        _12808 = float2(_9283.x - _12591.x, _9257 - _9283.y);
                        break;
                    } while(false);
                    float2 _5054 = float2(cbFI_DisplaySize);
                    _12810 = length(((_12591 + _12808) - _12592) * _5054) <= ((0.100000001490116119384765625f * length(_12808 * _5054)) + 8.0f);
                }
                else
                {
                    _12810 = _5033;
                }
                _12809 = _12810;
            }
            else
            {
                _12809 = true;
            }
            bool _5068 = !_12809;
            bool _15199 = _5068 ? false : _4972;
            bool _15200 = _5068 ? false : _4959;
            bool _12863;
            float4 _12894;
            if (!(((_4933 && _4946) && _15200) && _15199))
            {
                float4 _5090 = _12849 * float4(_4998, _5000, float(_15200), float(_15199));
                float _5092 = dot(_5090, 1.0f.xxxx);
                bool _5095 = !(_5092 > 0.0f);
                float4 _12895;
                if (!_5095)
                {
                    _12895 = _5090 / _5092.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9305;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9305);
                    }
                    _12895 = 0.0f.xxxx;
                }
                _12894 = _12895;
                _12863 = _5095;
            }
            else
            {
                _12894 = _12849;
                _12863 = false;
            }
            _14354 = float3(_4998, _5000, _12804);
            _12893 = _12894;
            _12862 = _12863;
        }
        else
        {
            _14354 = float3(float(_8953), _4917, 0.0f);
            _12893 = _12849;
            _12862 = false;
        }
        bool _5113 = !_12862;
        float4 _12978;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5113)
        {
            float _5120 = _12893.x + _12893.y;
            float4 _12979;
            if (_5120 > 0.001000000047497451305389404296875f)
            {
                _12979 = float4(_12893.x / _5120, _12893.y / _5120, 0.0f, 0.0f);
            }
            else
            {
                _12979 = float4(_4682, cbFI_Timestep, 0.0f, 0.0f);
            }
            _12978 = _12979;
        }
        else
        {
            _12978 = _12893;
        }
        float4 _13155;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5113) && _8953)
        {
            float _12952;
            do
            {
                uint4 _9445 = r_warped_motion_qdata_tp1.Load(int3(_12705, 0));
                uint _9446 = _9445.x;
                if (_9446 != 0u)
                {
                    float _12951;
                    if (_9446 == 0u)
                    {
                        _12951 = -1.0f;
                    }
                    else
                    {
                        _12951 = float((_9446 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12952 = _12951;
                    break;
                }
                int _12934;
                uint _12935;
                _12935 = _9446;
                _12934 = -1;
                uint _12950;
                for (; _12934 <= 1; _12935 = _12950, _12934++)
                {
                    _12950 = _12935;
                    for (int _12948 = -1; _12948 <= 1; )
                    {
                        _12950 = max(_12950, r_warped_motion_qdata_tp1.Load(int3(clamp(_12705 + int2(_12948, _12934), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _12948++;
                        continue;
                    }
                }
                if (_12935 != 0u)
                {
                    float _12947;
                    if (_12935 == 0u)
                    {
                        _12947 = -1.0f;
                    }
                    else
                    {
                        _12947 = float((_12935 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12952 = _12947;
                    break;
                }
                uint _12937;
                _12937 = 4294967295u;
                uint _15170;
                for (int _12936 = 0; _12936 < 8; _12937 = _15170, _12936++)
                {
                    int _12940 = 0;
                    for (;;)
                    {
                        if (_12940 < 5)
                        {
                            int2 _9396 = _12705 + (_1098[_12936] * _1107[_12940].xx);
                            bool _9399 = any(bool2(_9396.x < int2(0, 0).x, _9396.y < int2(0, 0).y));
                            bool _9407;
                            if (!_9399)
                            {
                                _9407 = any(bool2(_9396.x >= cbFI_MvDepthLaneSize.x, _9396.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _9407 = _9399;
                            }
                            if (_9407)
                            {
                                _15170 = _12937;
                                break;
                            }
                            uint4 _9485 = r_warped_motion_qdata_tp1.Load(int3(_9396, 0));
                            uint _9486 = _9485.x;
                            if (_9486 != 0u)
                            {
                                _15170 = min(_12937, _9486);
                                break;
                            }
                            _12940++;
                            continue;
                        }
                        else
                        {
                            _15170 = _12937;
                            break;
                        }
                    }
                }
                float _12939;
                if (_12937 == 4294967295u)
                {
                    _12939 = -1.0f;
                }
                else
                {
                    float _12938;
                    if (_12937 == 0u)
                    {
                        _12938 = -1.0f;
                    }
                    else
                    {
                        _12938 = float((_12937 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12939 = _12938;
                }
                _12952 = _12939;
                break;
            } while(false);
            float _5156 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5159 = r_warped_motion_qdata_tp1.Load(int3(_12705, 0)).x == 0u;
            bool _5165;
            if (_5159)
            {
                bool _9511 = all(bool2(_12588.x > 0.0f.xx.x, _12588.y > 0.0f.xx.y));
                bool _9517;
                if (_9511)
                {
                    _9517 = all(bool2(_12588.x < 1.0f.xx.x, _12588.y < 1.0f.xx.y));
                }
                else
                {
                    _9517 = _9511;
                }
                _5165 = _9517;
            }
            else
            {
                _5165 = _5159;
            }
            bool _5170;
            if (_5165)
            {
                bool _9522 = all(bool2(_12590.x > 0.0f.xx.x, _12590.y > 0.0f.xx.y));
                bool _9528;
                if (_9522)
                {
                    _9528 = all(bool2(_12590.x < 1.0f.xx.x, _12590.y < 1.0f.xx.y));
                }
                else
                {
                    _9528 = _9522;
                }
                _5170 = _9528;
            }
            else
            {
                _5170 = _5165;
            }
            bool _12964;
            float4 _12973;
            if (_5170)
            {
                uint _9535_dummy_parameter;
                float _9559 = log((r_depth_tm1.Load(int3(int2(floor(_12588 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9535_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _9567_dummy_parameter;
                float _9591 = log((r_depth_tp1.Load(int3(int2(floor(_12590 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9567_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _5181 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5188;
                if (_5181)
                {
                    _5188 = _9591 > (_9559 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5188 = _5181;
                }
                bool _12969;
                float4 _12991;
                if (_5188)
                {
                    _12991 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _12969 = true;
                }
                else
                {
                    bool _5194 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5201;
                    if (_5194)
                    {
                        _5201 = _9559 > (_9591 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5201 = _5194;
                    }
                    bool4 _15201 = _5201.xxxx;
                    _12991 = float4(_15201.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _12978.x, _15201.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _12978.y, _15201.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _12978.z, _15201.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _12978.w);
                    _12969 = _5201 ? true : false;
                }
                _12973 = _12991;
                _12964 = _12969;
            }
            else
            {
                _12973 = _12978;
                _12964 = false;
            }
            float4 _13046;
            if (_12964)
            {
                _13046 = 1.0f.xxxx;
            }
            else
            {
                bool _5212 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5218;
                if (_5212)
                {
                    _5218 = _12973.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5218 = _5212;
                }
                bool _5223;
                if (_5218)
                {
                    bool _9597 = all(bool2(_12590.x > 0.0f.xx.x, _12590.y > 0.0f.xx.y));
                    bool _9603;
                    if (_9597)
                    {
                        _9603 = all(bool2(_12590.x < 1.0f.xx.x, _12590.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9603 = _9597;
                    }
                    _5223 = _9603;
                }
                else
                {
                    _5223 = _5218;
                }
                float4 _13047;
                if (_5223)
                {
                    float _13000;
                    if (_12952 >= 0.0f)
                    {
                        _13000 = _12952 - _5156;
                    }
                    else
                    {
                        float _12996;
                        _12996 = 2.0f;
                        float _9660;
                        for (int _12995 = 0; _12995 < 24; _12996 = _9660, _12995++)
                        {
                            float _9624 = float(_12995 & 7) * 0.785398185253143310546875f;
                            int _9626 = _12995 >> 3;
                            int _12997;
                            if (_9626 == 0)
                            {
                                _12997 = 16;
                            }
                            else
                            {
                                _12997 = (_9626 == 1) ? 48 : 96;
                            }
                            uint _9692_dummy_parameter;
                            _9660 = min(_12996, log((r_depth_tp1.Load(int3(int2(floor(clamp(_12590 + ((cbFI_MvDepthLaneSizeRcp * float(_12997)) * float2(cos(_9624), sin(_9624))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9692_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _13000 = _12996;
                    }
                    uint _9724_dummy_parameter;
                    float4 _13048;
                    if (r_depth_tp1.Load(int3(int2(floor(_12590 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9724_dummy_parameter))))), 0)).x > ((exp((_13000 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _13048 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _13048 = 1.0f.xxxx;
                    }
                    _13047 = _13048;
                }
                else
                {
                    _13047 = 1.0f.xxxx;
                }
                _13046 = _13047;
            }
            bool _5251 = _12952 >= 0.0f;
            bool _5252 = (!_12964) && _5251;
            bool _5259;
            if (_5252)
            {
                _5259 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5259 = _5252;
            }
            bool _5265;
            if (_5259)
            {
                _5265 = _12973.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5265 = _5259;
            }
            bool _5270;
            if (_5265)
            {
                bool _9748 = all(bool2(_12588.x > 0.0f.xx.x, _12588.y > 0.0f.xx.y));
                bool _9754;
                if (_9748)
                {
                    _9754 = all(bool2(_12588.x < 1.0f.xx.x, _12588.y < 1.0f.xx.y));
                }
                else
                {
                    _9754 = _9748;
                }
                _5270 = _9754;
            }
            else
            {
                _5270 = _5265;
            }
            float4 _13071;
            if (_5270)
            {
                float _13040;
                if (_5251)
                {
                    _13040 = _12952 - _5156;
                }
                else
                {
                    float _13036;
                    _13036 = 2.0f;
                    float _9811;
                    for (int _13035 = 0; _13035 < 24; _13036 = _9811, _13035++)
                    {
                        float _9775 = float(_13035 & 7) * 0.785398185253143310546875f;
                        int _9777 = _13035 >> 3;
                        int _13037;
                        if (_9777 == 0)
                        {
                            _13037 = 16;
                        }
                        else
                        {
                            _13037 = (_9777 == 1) ? 48 : 96;
                        }
                        uint _9827_dummy_parameter;
                        _9811 = min(_13036, log((r_depth_tm1.Load(int3(int2(floor(clamp(_12588 + ((cbFI_MvDepthLaneSizeRcp * float(_13037)) * float2(cos(_9775), sin(_9775))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9827_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _13040 = _13036;
                }
                uint _9875_dummy_parameter;
                float4 _13072;
                if (r_depth_tm1.Load(int3(int2(floor(_12588 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9875_dummy_parameter))))), 0)).x > ((exp((_13040 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _12420 = _13046;
                    _12420.x = 0.0f;
                    _13072 = _12420;
                }
                else
                {
                    _13072 = _13046;
                }
                _13071 = _13072;
            }
            else
            {
                _13071 = _13046;
            }
            float4 _13084;
            if (_5252)
            {
                float _9901 = (exp(((_12952 - _5156) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5308 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5314;
                if (_5308)
                {
                    _5314 = _12973.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5314 = _5308;
                }
                bool _5319;
                if (_5314)
                {
                    bool _9906 = all(bool2(_12592.x > 0.0f.xx.x, _12592.y > 0.0f.xx.y));
                    bool _9912;
                    if (_9906)
                    {
                        _9912 = all(bool2(_12592.x < 1.0f.xx.x, _12592.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9912 = _9906;
                    }
                    _5319 = _9912;
                }
                else
                {
                    _5319 = _5314;
                }
                bool _5327;
                if (_5319)
                {
                    uint _9919_dummy_parameter;
                    _5327 = r_depth_tp1.Load(int3(int2(floor(_12592 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9919_dummy_parameter))))), 0)).x > _9901;
                }
                else
                {
                    _5327 = _5319;
                }
                float4 _13082;
                if (_5327)
                {
                    float4 _12423 = _13071;
                    _12423.w = 0.0f;
                    _13082 = _12423;
                }
                else
                {
                    _13082 = _13071;
                }
                bool _5334 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5340;
                if (_5334)
                {
                    _5340 = _12973.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5340 = _5334;
                }
                bool _5345;
                if (_5340)
                {
                    bool _9936 = all(bool2(_12591.x > 0.0f.xx.x, _12591.y > 0.0f.xx.y));
                    bool _9942;
                    if (_9936)
                    {
                        _9942 = all(bool2(_12591.x < 1.0f.xx.x, _12591.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9942 = _9936;
                    }
                    _5345 = _9942;
                }
                else
                {
                    _5345 = _5340;
                }
                bool _5353;
                if (_5345)
                {
                    uint _9949_dummy_parameter;
                    _5353 = r_depth_tm1.Load(int3(int2(floor(_12591 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9949_dummy_parameter))))), 0)).x > _9901;
                }
                else
                {
                    _5353 = _5345;
                }
                float4 _13085;
                if (_5353)
                {
                    float4 _12426 = _13082;
                    _12426.z = 0.0f;
                    _13085 = _12426;
                }
                else
                {
                    _13085 = _13082;
                }
                _13084 = _13085;
            }
            else
            {
                _13084 = _13071;
            }
            float4 _13156;
            if (any(bool4(_13084.x < 1.0f.xxxx.x, _13084.y < 1.0f.xxxx.y, _13084.z < 1.0f.xxxx.z, _13084.w < 1.0f.xxxx.w)))
            {
                float4 _5364 = _12973 * _13084;
                float _5366 = dot(_5364, 1.0f.xxxx);
                float4 _13157;
                if (_5366 > 0.0f)
                {
                    _13157 = _5364 / _5366.xxxx;
                }
                else
                {
                    bool _5377 = _13084.y == 0.0f;
                    bool _5383;
                    if (_5377)
                    {
                        _5383 = _13084.x > 0.0f;
                    }
                    else
                    {
                        _5383 = _5377;
                    }
                    bool _5388;
                    if (_5383)
                    {
                        bool _9966 = all(bool2(_12588.x > 0.0f.xx.x, _12588.y > 0.0f.xx.y));
                        bool _9972;
                        if (_9966)
                        {
                            _9972 = all(bool2(_12588.x < 1.0f.xx.x, _12588.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _9972 = _9966;
                        }
                        _5388 = _9972;
                    }
                    else
                    {
                        _5388 = _5383;
                    }
                    float4 _13158;
                    if (_5388)
                    {
                        _13158 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5393 = _13084.x == 0.0f;
                        bool _5399;
                        if (_5393)
                        {
                            _5399 = _13084.y > 0.0f;
                        }
                        else
                        {
                            _5399 = _5393;
                        }
                        bool _5404;
                        if (_5399)
                        {
                            bool _9977 = all(bool2(_12590.x > 0.0f.xx.x, _12590.y > 0.0f.xx.y));
                            bool _9983;
                            if (_9977)
                            {
                                _9983 = all(bool2(_12590.x < 1.0f.xx.x, _12590.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _9983 = _9977;
                            }
                            _5404 = _9983;
                        }
                        else
                        {
                            _5404 = _5399;
                        }
                        bool4 _15204 = _5404.xxxx;
                        _13158 = float4(_15204.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _12973.x, _15204.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _12973.y, _15204.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _12973.z, _15204.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _12973.w);
                    }
                    _13157 = _13158;
                }
                _13156 = _13157;
            }
            else
            {
                _13156 = _12973;
            }
            _13155 = _13156;
        }
        else
        {
            _13155 = _12978;
        }
        float4 _13769;
        bool _14031;
        float3 _14148;
        if (((cbFI_pad0 & 32768u) != 0u) && _5113)
        {
            bool _5421 = _13155.x > 0.00999999977648258209228515625f;
            bool _5424 = _13155.y > 0.00999999977648258209228515625f;
            bool _5433 = (_13155.z + _13155.w) > 0.0199999995529651641845703125f;
            bool _5439;
            if (_5433)
            {
                bool _9988 = all(bool2(_12591.x > 0.0f.xx.x, _12591.y > 0.0f.xx.y));
                bool _9994;
                if (_9988)
                {
                    _9994 = all(bool2(_12591.x < 1.0f.xx.x, _12591.y < 1.0f.xx.y));
                }
                else
                {
                    _9994 = _9988;
                }
                _5439 = _9994;
            }
            else
            {
                _5439 = _5433;
            }
            bool _5444;
            if (_5439)
            {
                bool _9999 = all(bool2(_12592.x > 0.0f.xx.x, _12592.y > 0.0f.xx.y));
                bool _10005;
                if (_9999)
                {
                    _10005 = all(bool2(_12592.x < 1.0f.xx.x, _12592.y < 1.0f.xx.y));
                }
                else
                {
                    _10005 = _9999;
                }
                _5444 = _10005;
            }
            else
            {
                _5444 = _5439;
            }
            bool _5451;
            if (_5444)
            {
                float _13166;
                do
                {
                    bool _10088 = all(bool2(_12591.x > 0.0f.xx.x, _12591.y > 0.0f.xx.y));
                    bool _10094;
                    if (_10088)
                    {
                        _10094 = all(bool2(_12591.x < 1.0f.xx.x, _12591.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10094 = _10088;
                    }
                    bool _10025 = !_10094;
                    bool _10032;
                    if (!_10025)
                    {
                        bool _10099 = all(bool2(_12592.x > 0.0f.xx.x, _12592.y > 0.0f.xx.y));
                        bool _10105;
                        if (_10099)
                        {
                            _10105 = all(bool2(_12592.x < 1.0f.xx.x, _12592.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _10105 = _10099;
                        }
                        _10032 = !_10105;
                    }
                    else
                    {
                        _10032 = _10025;
                    }
                    if (_10032)
                    {
                        _13166 = 0.0f;
                        break;
                    }
                    uint _10112_dummy_parameter;
                    uint _10128_dummy_parameter;
                    float4 _10053 = mul(float4((float2(_12591.x, 1.0f - _12591.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12591 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10112_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _10055 = _10053.w;
                    if (abs(_10055) < 9.9999999747524270787835121154785e-07f)
                    {
                        _13166 = 0.0f;
                        break;
                    }
                    float _10066 = abs(cbFI_DeviceToViewDepth.y / ((_10053.z / _10055) - cbFI_DeviceToViewDepth.x));
                    float _10069 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12592 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10128_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _13166 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_10066 - _10069) / max(max(_10066, _10069), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5451 = _13166 < 0.5f;
            }
            else
            {
                _5451 = _5444;
            }
            float4 _13181;
            if (_5451)
            {
                uint _10178_dummy_parameter;
                uint _10209_dummy_parameter;
                float4 _13182;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_12591 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10178_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12592 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10209_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _13182 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _13182 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _13181 = _13182;
            }
            else
            {
                _13181 = 1.0f.xxxx;
            }
            bool _5475;
            if (_8953)
            {
                bool _10238 = all(bool2(_12588.x > 0.0f.xx.x, _12588.y > 0.0f.xx.y));
                bool _10244;
                if (_10238)
                {
                    _10244 = all(bool2(_12588.x < 1.0f.xx.x, _12588.y < 1.0f.xx.y));
                }
                else
                {
                    _10244 = _10238;
                }
                _5475 = _10244;
            }
            else
            {
                _5475 = _8953;
            }
            bool _5481;
            if (_8953)
            {
                bool _10249 = all(bool2(_12590.x > 0.0f.xx.x, _12590.y > 0.0f.xx.y));
                bool _10255;
                if (_10249)
                {
                    _10255 = all(bool2(_12590.x < 1.0f.xx.x, _12590.y < 1.0f.xx.y));
                }
                else
                {
                    _10255 = _10249;
                }
                _5481 = _10255;
            }
            else
            {
                _5481 = _8953;
            }
            bool _5487;
            if (_8985)
            {
                bool _10260 = all(bool2(_12591.x > 0.0f.xx.x, _12591.y > 0.0f.xx.y));
                bool _10266;
                if (_10260)
                {
                    _10266 = all(bool2(_12591.x < 1.0f.xx.x, _12591.y < 1.0f.xx.y));
                }
                else
                {
                    _10266 = _10260;
                }
                _5487 = _10266;
            }
            else
            {
                _5487 = _8985;
            }
            bool _5493;
            if (_8985)
            {
                bool _10271 = all(bool2(_12592.x > 0.0f.xx.x, _12592.y > 0.0f.xx.y));
                bool _10277;
                if (_10271)
                {
                    _10277 = all(bool2(_12592.x < 1.0f.xx.x, _12592.y < 1.0f.xx.y));
                }
                else
                {
                    _10277 = _10271;
                }
                _5493 = _10277;
            }
            else
            {
                _5493 = _8985;
            }
            bool _5496 = _5487 != _5493;
            bool _5502;
            if (_5496)
            {
                _5502 = _5475 || _5481;
            }
            else
            {
                _5502 = _5496;
            }
            float4 _13280;
            if (_5502)
            {
                float4 _12453 = _13181;
                _12453.z = 0.0f;
                _12453.w = 0.0f;
                _13280 = _12453;
            }
            else
            {
                _13280 = _13181;
            }
            bool _5509 = _5475 && _5421;
            bool _5512 = _5481 && _5424;
            float4 _13385;
            float3 _14249;
            if (_5509 || _5512)
            {
                float _13275;
                do
                {
                    uint4 _10416 = r_warped_motion_qdata_tp1.Load(int3(_12705, 0));
                    uint _10417 = _10416.x;
                    if (_10417 != 0u)
                    {
                        float _13274;
                        if (_10417 == 0u)
                        {
                            _13274 = -1.0f;
                        }
                        else
                        {
                            _13274 = float((_10417 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13275 = _13274;
                        break;
                    }
                    int _13257;
                    uint _13258;
                    _13258 = _10417;
                    _13257 = -1;
                    uint _13273;
                    for (; _13257 <= 1; _13258 = _13273, _13257++)
                    {
                        _13273 = _13258;
                        for (int _13271 = -1; _13271 <= 1; )
                        {
                            _13273 = max(_13273, r_warped_motion_qdata_tp1.Load(int3(clamp(_12705 + int2(_13271, _13257), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _13271++;
                            continue;
                        }
                    }
                    if (_13258 != 0u)
                    {
                        float _13270;
                        if (_13258 == 0u)
                        {
                            _13270 = -1.0f;
                        }
                        else
                        {
                            _13270 = float((_13258 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13275 = _13270;
                        break;
                    }
                    uint _13260;
                    _13260 = 4294967295u;
                    uint _15171;
                    for (int _13259 = 0; _13259 < 8; _13260 = _15171, _13259++)
                    {
                        int _13263 = 0;
                        for (;;)
                        {
                            if (_13263 < 5)
                            {
                                int2 _10367 = _12705 + (_1098[_13259] * _1107[_13263].xx);
                                bool _10370 = any(bool2(_10367.x < int2(0, 0).x, _10367.y < int2(0, 0).y));
                                bool _10378;
                                if (!_10370)
                                {
                                    _10378 = any(bool2(_10367.x >= cbFI_MvDepthLaneSize.x, _10367.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _10378 = _10370;
                                }
                                if (_10378)
                                {
                                    _15171 = _13260;
                                    break;
                                }
                                uint4 _10456 = r_warped_motion_qdata_tp1.Load(int3(_10367, 0));
                                uint _10457 = _10456.x;
                                if (_10457 != 0u)
                                {
                                    _15171 = min(_13260, _10457);
                                    break;
                                }
                                _13263++;
                                continue;
                            }
                            else
                            {
                                _15171 = _13260;
                                break;
                            }
                        }
                    }
                    float _13262;
                    if (_13260 == 4294967295u)
                    {
                        _13262 = -1.0f;
                    }
                    else
                    {
                        float _13261;
                        if (_13260 == 0u)
                        {
                            _13261 = -1.0f;
                        }
                        else
                        {
                            _13261 = float((_13260 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13262 = _13261;
                    }
                    _13275 = _13262;
                    break;
                } while(false);
                bool _5520 = _13275 < 0.0f;
                float _13276;
                if (_5520)
                {
                    _13276 = 0.0f;
                }
                else
                {
                    _13276 = _13275 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _10478_dummy_parameter;
                uint _10510_dummy_parameter;
                float4 _13313;
                if ((_5520 && _5509) && _5512)
                {
                    uint _10542_dummy_parameter;
                    float _10566 = log((r_depth_tm1.Load(int3(int2(floor(_12588 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10542_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _10574_dummy_parameter;
                    float _10598 = log((r_depth_tp1.Load(int3(int2(floor(_12590 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10574_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _13314;
                    if (_10566 > (_10598 + 0.07999999821186065673828125f))
                    {
                        float4 _12457 = _13280;
                        _12457.x = 0.0f;
                        _13314 = _12457;
                    }
                    else
                    {
                        float4 _13315;
                        if (_10598 > (_10566 + 0.07999999821186065673828125f))
                        {
                            float4 _12459 = _13280;
                            _12459.y = 0.0f;
                            _13315 = _12459;
                        }
                        else
                        {
                            _13315 = _13280;
                        }
                        _13314 = _13315;
                    }
                    _13313 = _13314;
                }
                else
                {
                    _13313 = _13280;
                }
                float _5572 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5574 = _13275 >= 0.0f;
                float _13296;
                if (_5574)
                {
                    _13296 = _13275 - _5572;
                }
                else
                {
                    float _13292;
                    if (_5509)
                    {
                        float _13291;
                        _13291 = 2.0f;
                        float _10656;
                        for (int _13290 = 0; _13290 < 24; _13291 = _10656, _13290++)
                        {
                            float _10620 = float(_13290 & 7) * 0.785398185253143310546875f;
                            int _10622 = _13290 >> 3;
                            int _13293;
                            if (_10622 == 0)
                            {
                                _13293 = 16;
                            }
                            else
                            {
                                _13293 = (_10622 == 1) ? 48 : 96;
                            }
                            uint _10672_dummy_parameter;
                            _10656 = min(_13291, log((r_depth_tm1.Load(int3(int2(floor(clamp(_12588 + ((cbFI_MvDepthLaneSizeRcp * float(_13293)) * float2(cos(_10620), sin(_10620))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10672_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _13292 = _13291;
                    }
                    else
                    {
                        _13292 = 0.0f;
                    }
                    _13296 = _13292;
                }
                float _13303;
                if (_5574)
                {
                    _13303 = _13275 - _5572;
                }
                else
                {
                    float _13299;
                    if (_5512)
                    {
                        float _13298;
                        _13298 = 2.0f;
                        float _10770;
                        for (int _13297 = 0; _13297 < 24; _13298 = _10770, _13297++)
                        {
                            float _10734 = float(_13297 & 7) * 0.785398185253143310546875f;
                            int _10736 = _13297 >> 3;
                            int _13300;
                            if (_10736 == 0)
                            {
                                _13300 = 16;
                            }
                            else
                            {
                                _13300 = (_10736 == 1) ? 48 : 96;
                            }
                            uint _10802_dummy_parameter;
                            _10770 = min(_13298, log((r_depth_tp1.Load(int3(int2(floor(clamp(_12590 + ((cbFI_MvDepthLaneSizeRcp * float(_13300)) * float2(cos(_10734), sin(_10734))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10802_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _13299 = _13298;
                    }
                    else
                    {
                        _13299 = 0.0f;
                    }
                    _13303 = _13299;
                }
                float _13304;
                if (_5509)
                {
                    uint _10834_dummy_parameter;
                    _13304 = r_depth_tm1.Load(int3(int2(floor(_12588 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10834_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _13304 = 0.0f;
                }
                float _13305;
                if (_5512)
                {
                    uint _10853_dummy_parameter;
                    _13305 = r_depth_tp1.Load(int3(int2(floor(_12590 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10853_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _13305 = 0.0f;
                }
                bool _5629;
                if (_5509)
                {
                    _5629 = _13304 > ((exp((_13296 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5629 = _5509;
                }
                float4 _13321;
                if (_5629)
                {
                    float4 _12461 = _13313;
                    _12461.x = 0.0f;
                    _13321 = _12461;
                }
                else
                {
                    _13321 = _13313;
                }
                bool _5641;
                if (_5512)
                {
                    _5641 = _13305 > ((exp((_13303 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5641 = _5512;
                }
                float4 _13323;
                if (_5641)
                {
                    float4 _12463 = _13321;
                    _12463.y = 0.0f;
                    _13323 = _12463;
                }
                else
                {
                    _13323 = _13321;
                }
                float4 _13386;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5574)
                {
                    bool _5661;
                    if (_5509)
                    {
                        _5661 = _13304 < ((exp((_13296 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5661 = _5509;
                    }
                    float4 _13325;
                    if (_5661)
                    {
                        float4 _12465 = _13323;
                        _12465.x = 0.0f;
                        _13325 = _12465;
                    }
                    else
                    {
                        _13325 = _13323;
                    }
                    bool _5673;
                    if (_5512)
                    {
                        _5673 = _13305 < ((exp((_13303 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5673 = _5512;
                    }
                    float4 _13387;
                    if (_5673)
                    {
                        float4 _12467 = _13325;
                        _12467.y = 0.0f;
                        _13387 = _12467;
                    }
                    else
                    {
                        _13387 = _13325;
                    }
                    _13386 = _13387;
                }
                else
                {
                    _13386 = _13323;
                }
                _14249 = float3(_13276, log((r_depth_tm1.Load(int3(int2(floor(_12588 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10478_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_12590 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10510_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _13385 = _13386;
            }
            else
            {
                _14249 = float3(0.0f, 0.0f, 0.5f);
                _13385 = _13280;
            }
            bool _5684 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5433;
            bool _5690;
            if (_5684)
            {
                _5690 = _5487 || _5493;
            }
            else
            {
                _5690 = _5684;
            }
            float4 _13408;
            if (_5690)
            {
                float _13380;
                do
                {
                    uint4 _11032 = r_warped_motion_qdata_tp1.Load(int3(_12705, 0));
                    uint _11033 = _11032.x;
                    if (_11033 != 0u)
                    {
                        float _13379;
                        if (_11033 == 0u)
                        {
                            _13379 = -1.0f;
                        }
                        else
                        {
                            _13379 = float((_11033 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13380 = _13379;
                        break;
                    }
                    int _13362;
                    uint _13363;
                    _13363 = _11033;
                    _13362 = -1;
                    uint _13378;
                    for (; _13362 <= 1; _13363 = _13378, _13362++)
                    {
                        _13378 = _13363;
                        for (int _13376 = -1; _13376 <= 1; )
                        {
                            _13378 = max(_13378, r_warped_motion_qdata_tp1.Load(int3(clamp(_12705 + int2(_13376, _13362), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _13376++;
                            continue;
                        }
                    }
                    if (_13363 != 0u)
                    {
                        float _13375;
                        if (_13363 == 0u)
                        {
                            _13375 = -1.0f;
                        }
                        else
                        {
                            _13375 = float((_13363 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13380 = _13375;
                        break;
                    }
                    uint _13365;
                    _13365 = 4294967295u;
                    uint _15172;
                    for (int _13364 = 0; _13364 < 8; _13365 = _15172, _13364++)
                    {
                        int _13368 = 0;
                        for (;;)
                        {
                            if (_13368 < 5)
                            {
                                int2 _10983 = _12705 + (_1098[_13364] * _1107[_13368].xx);
                                bool _10986 = any(bool2(_10983.x < int2(0, 0).x, _10983.y < int2(0, 0).y));
                                bool _10994;
                                if (!_10986)
                                {
                                    _10994 = any(bool2(_10983.x >= cbFI_MvDepthLaneSize.x, _10983.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _10994 = _10986;
                                }
                                if (_10994)
                                {
                                    _15172 = _13365;
                                    break;
                                }
                                uint4 _11072 = r_warped_motion_qdata_tp1.Load(int3(_10983, 0));
                                uint _11073 = _11072.x;
                                if (_11073 != 0u)
                                {
                                    _15172 = min(_13365, _11073);
                                    break;
                                }
                                _13368++;
                                continue;
                            }
                            else
                            {
                                _15172 = _13365;
                                break;
                            }
                        }
                    }
                    float _13367;
                    if (_13365 == 4294967295u)
                    {
                        _13367 = -1.0f;
                    }
                    else
                    {
                        float _13366;
                        if (_13365 == 0u)
                        {
                            _13366 = -1.0f;
                        }
                        else
                        {
                            _13366 = float((_13365 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13367 = _13366;
                    }
                    _13380 = _13367;
                    break;
                } while(false);
                float4 _13409;
                if (_13380 >= 0.0f)
                {
                    float _11094 = (exp((_13380 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5709;
                    if (_5487)
                    {
                        uint _11101_dummy_parameter;
                        _5709 = r_depth_tm1.Load(int3(int2(floor(_12591 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11101_dummy_parameter))))), 0)).x > _11094;
                    }
                    else
                    {
                        _5709 = _5487;
                    }
                    float4 _13398;
                    if (_5709)
                    {
                        float4 _12469 = _13385;
                        _12469.z = 0.0f;
                        _13398 = _12469;
                    }
                    else
                    {
                        _13398 = _13385;
                    }
                    bool _5721;
                    if (_5493)
                    {
                        uint _11120_dummy_parameter;
                        _5721 = r_depth_tp1.Load(int3(int2(floor(_12592 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11120_dummy_parameter))))), 0)).x > _11094;
                    }
                    else
                    {
                        _5721 = _5493;
                    }
                    float4 _13410;
                    if (_5721)
                    {
                        float4 _12471 = _13398;
                        _12471.w = 0.0f;
                        _13410 = _12471;
                    }
                    else
                    {
                        _13410 = _13398;
                    }
                    _13409 = _13410;
                }
                else
                {
                    _13409 = _13385;
                }
                _13408 = _13409;
            }
            else
            {
                _13408 = _13385;
            }
            bool _5729 = _5475 != _5481;
            bool _5736;
            if (_5729)
            {
                _5736 = _5475 ? _5421 : _5424;
            }
            else
            {
                _5736 = _5729;
            }
            bool _5743;
            if (_5736)
            {
                _5743 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5743 = _5736;
            }
            float4 _13493;
            if (_5743)
            {
                bool2 _5748 = _5475.xx;
                float2 _5749 = float2(_5748.x ? _12588.x : _12590.x, _5748.y ? _12588.y : _12590.y);
                float _13400;
                if (_5475)
                {
                    uint _11139_dummy_parameter;
                    _13400 = r_depth_tm1.Load(int3(int2(floor(_5749 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11139_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _11155_dummy_parameter;
                    _13400 = r_depth_tp1.Load(int3(int2(floor(_5749 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11155_dummy_parameter))))), 0)).x;
                }
                float4x4 _13401;
                if (_5475)
                {
                    _13401 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _13401 = cbFI_MotionTP1ToTM1;
                }
                float2 _13402;
                do
                {
                    float _11182 = _5749.x;
                    float _11185 = 1.0f - _5749.y;
                    float4 _11196 = mul(float4((float2(_11182, _11185) * 2.0f) - 1.0f.xx, _13400, 1.0f), _13401);
                    float _11198 = _11196.w;
                    if (!(_11198 > 9.9999999747524270787835121154785e-07f))
                    {
                        _13402 = 1000000.0f.xx;
                        break;
                    }
                    float2 _11211 = ((_11196.xy / _11198.xx) + 1.0f.xx) * 0.5f;
                    _13402 = float2(_11211.x - _11182, _11185 - _11211.y);
                    break;
                } while(false);
                float2 _5779 = float2(cbFI_DisplaySize);
                float4 _13494;
                if (!(length(((_5749 + _13402) - float2(_5748.x ? _12590.x : _12588.x, _5748.y ? _12590.y : _12588.y)) * _5779) <= ((0.100000001490116119384765625f * length(_13402 * _5779)) + 8.0f)))
                {
                    float4 _13495;
                    if (_5475)
                    {
                        float4 _12481 = _13408;
                        _12481.x = 0.0f;
                        _13495 = _12481;
                    }
                    else
                    {
                        float4 _12483 = _13408;
                        _12483.y = 0.0f;
                        _13495 = _12483;
                    }
                    _13494 = _13495;
                }
                else
                {
                    _13494 = _13408;
                }
                _13493 = _13494;
            }
            else
            {
                _13493 = _13408;
            }
            float4 _5804 = _13155 * _13493;
            float _5806 = dot(_5804, 1.0f.xxxx);
            float4 _13770;
            bool _14032;
            if (_5806 > 0.0f)
            {
                _14032 = _12862;
                _13770 = _5804 / _5806.xxxx;
            }
            else
            {
                bool _5817 = any(bool4(_13493.x < 1.0f.xxxx.x, _13493.y < 1.0f.xxxx.y, _13493.z < 1.0f.xxxx.z, _13493.w < 1.0f.xxxx.w));
                if (_5817)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11233;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11233);
                    }
                }
                bool4 _15207 = _5817.xxxx;
                _14032 = _5817 ? true : _12862;
                _13770 = float4(_15207.x ? 0.0f.xxxx.x : _13155.x, _15207.y ? 0.0f.xxxx.y : _13155.y, _15207.z ? 0.0f.xxxx.z : _13155.z, _15207.w ? 0.0f.xxxx.w : _13155.w);
            }
            _14148 = _14249;
            _14031 = _14032;
            _13769 = _13770;
        }
        else
        {
            _14148 = float3(0.0f, 0.0f, 0.5f);
            _14031 = _12862;
            _13769 = _13155;
        }
        uint _5826 = (cbFI_pad0 >> 24u) & 31u;
        uint _5830 = (cbFI_pad0 >> 16u) & 255u;
        bool _5832 = _5826 != 0u;
        bool _5834 = _5830 == 12u;
        bool _5837 = _5830 == 13u;
        float4 _13786;
        if ((_5832 || _5834) || _5837)
        {
            float _13496;
            do
            {
                bool _11317 = all(bool2(_12591.x > 0.0f.xx.x, _12591.y > 0.0f.xx.y));
                bool _11323;
                if (_11317)
                {
                    _11323 = all(bool2(_12591.x < 1.0f.xx.x, _12591.y < 1.0f.xx.y));
                }
                else
                {
                    _11323 = _11317;
                }
                bool _11254 = !_11323;
                bool _11261;
                if (!_11254)
                {
                    bool _11328 = all(bool2(_12592.x > 0.0f.xx.x, _12592.y > 0.0f.xx.y));
                    bool _11334;
                    if (_11328)
                    {
                        _11334 = all(bool2(_12592.x < 1.0f.xx.x, _12592.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11334 = _11328;
                    }
                    _11261 = !_11334;
                }
                else
                {
                    _11261 = _11254;
                }
                if (_11261)
                {
                    _13496 = 0.0f;
                    break;
                }
                uint _11341_dummy_parameter;
                uint _11357_dummy_parameter;
                float4 _11282 = mul(float4((float2(_12591.x, 1.0f - _12591.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12591 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11341_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _11284 = _11282.w;
                if (abs(_11284) < 9.9999999747524270787835121154785e-07f)
                {
                    _13496 = 0.0f;
                    break;
                }
                float _11295 = abs(cbFI_DeviceToViewDepth.y / ((_11282.z / _11284) - cbFI_DeviceToViewDepth.x));
                float _11298 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12592 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11357_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _13496 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11295 - _11298) / max(max(_11295, _11298), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _11405 = all(bool2(_12592.x > 0.0f.xx.x, _12592.y > 0.0f.xx.y));
            bool _11411;
            if (_11405)
            {
                _11411 = all(bool2(_12592.x < 1.0f.xx.x, _12592.y < 1.0f.xx.y));
            }
            else
            {
                _11411 = _11405;
            }
            float _13497;
            if (_11411)
            {
                uint _11418_dummy_parameter;
                _13497 = length((_6667 + (r_motion_tp1.Load(int3(int2(floor(_12592 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _11418_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _13497 = 1000000.0f;
            }
            float _13508;
            if ((_5826 & 1u) != 0u)
            {
                _13508 = _13496;
            }
            else
            {
                _13508 = 1.0f;
            }
            float _13509;
            if ((_5826 & 2u) != 0u)
            {
                _13509 = _13508 * (1.0f - smoothstep(2.0f, 8.0f, _13497));
            }
            else
            {
                _13509 = _13508;
            }
            float _13510;
            if ((_5826 & 4u) != 0u)
            {
                _13510 = _13509 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7388 - _7396) - length(_7372 - _7380))));
            }
            else
            {
                _13510 = _13509;
            }
            float _13780;
            if ((_5826 & 8u) != 0u)
            {
                _13780 = lerp(1.0f, _13510, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7372 - _7380)));
            }
            else
            {
                _13780 = _13510;
            }
            bool _5912 = (_5826 & 16u) != 0u;
            bool _5921;
            if (_5912)
            {
                _5921 = length(_12586 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5921 = _5912;
            }
            float _15209 = _5921 ? 1.0f : _13780;
            bool _5927 = _5832 && _8953;
            bool _5932;
            if (_5927)
            {
                bool _11443 = all(bool2(_12588.x > 0.0f.xx.x, _12588.y > 0.0f.xx.y));
                bool _11449;
                if (_11443)
                {
                    _11449 = all(bool2(_12588.x < 1.0f.xx.x, _12588.y < 1.0f.xx.y));
                }
                else
                {
                    _11449 = _11443;
                }
                _5932 = _11449;
            }
            else
            {
                _5932 = _5927;
            }
            bool _5937;
            if (_5932)
            {
                bool _11454 = all(bool2(_12590.x > 0.0f.xx.x, _12590.y > 0.0f.xx.y));
                bool _11460;
                if (_11454)
                {
                    _11460 = all(bool2(_12590.x < 1.0f.xx.x, _12590.y < 1.0f.xx.y));
                }
                else
                {
                    _11460 = _11454;
                }
                _5937 = _11460;
            }
            else
            {
                _5937 = _5932;
            }
            float4 _13787;
            if (_5937)
            {
                float _5943 = _13769.x + _13769.y;
                float _5952 = (_13769.z + _13769.w) * (1.0f - _15209);
                float _13783;
                if (_5943 > 9.9999997473787516355514526367188e-06f)
                {
                    _13783 = _13769.x / _5943;
                }
                else
                {
                    _13783 = _4682;
                }
                _13787 = float4(_13769.x + (_5952 * _13783), _13769.y + (_5952 * (1.0f - _13783)), _13769.zw * _15209);
            }
            else
            {
                _13787 = _13769;
            }
            _13786 = _13787;
        }
        else
        {
            _13786 = _13769;
        }
        float3 _6013 = (((_7372 * _13786.x) + (_7380 * _13786.y)) + (_7388 * _13786.z)) + (_7396 * _13786.w);
        float3 _14974;
        if (_4698 && (_13801 > 0.0f))
        {
            uint _11467_dummy_parameter;
            float2 _11482 = r_motion_tp1.Load(int3(int2(floor(_4457 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _11467_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _14023;
            if (_6695)
            {
                float2 _11527 = clamp((((_12565 + (_11482 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _11530 = tan(_11527.x);
                _14023 = (float2(_11530 / cbFI_DeviceToViewDepth.z, (tan(_11527.y) * sqrt(1.0f + (_11530 * _11530))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _14023 = _12565 + (_11482 * cbFI_Timestep);
            }
            float2 _14024;
            if (_6695)
            {
                float2 _11606 = clamp((((_12565 + (_11482 * _4672)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _11609 = tan(_11606.x);
                _14024 = (float2(_11609 / cbFI_DeviceToViewDepth.z, (tan(_11606.y) * sqrt(1.0f + (_11609 * _11609))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _14024 = _12565 + (_11482 * _4672);
            }
            _14974 = lerp(_6013, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14023, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _14024, 0.0f).xyz, cbFI_Timestep.xxx), _13801.xxx);
        }
        else
        {
            _14974 = _6013;
        }
        float3 _14973;
        if (_14031)
        {
            float3 _11651 = r_current_interpolation_source.Load(int3(_3998, 0)).xyz;
            float3 _14975;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _8953)
            {
                uint _11658_dummy_parameter;
                float _14138;
                _14138 = r_depth_tm1.Load(int3(int2(floor(_12588 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11658_dummy_parameter))))), 0)).x;
                float _6094;
                for (int _14137 = 0; _14137 < 24; _14138 = _6094, _14137++)
                {
                    float _6066 = float(_14137 & 7) * 0.785398185253143310546875f;
                    int _6068 = _14137 >> 3;
                    int _15025;
                    if (_6068 == 0)
                    {
                        _15025 = 16;
                    }
                    else
                    {
                        _15025 = (_6068 == 1) ? 48 : 96;
                    }
                    uint _11678_dummy_parameter;
                    _6094 = min(_14138, r_depth_tm1.Load(int3(int2(floor(clamp(_12588 + ((cbFI_MvDepthLaneSizeRcp * float(_15025)) * float2(cos(_6066), sin(_6066))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11678_dummy_parameter))))), 0)).x);
                }
                float2 _14139;
                do
                {
                    float _11700 = 1.0f - _12588.y;
                    float4 _11711 = mul(float4((float2(_12588.x, _11700) * 2.0f) - 1.0f.xx, _14138, 1.0f), cbFI_MotionTM1ToTM2);
                    float _11713 = _11711.w;
                    if (!(_11713 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14139 = 1000000.0f.xx;
                        break;
                    }
                    float2 _11726 = ((_11711.xy / _11713.xx) + 1.0f.xx) * 0.5f;
                    _14139 = float2(_11726.x - _12588.x, _11700 - _11726.y);
                    break;
                } while(false);
                float2 _6105 = _12588 + _14139;
                bool _11744 = all(bool2(_6105.x > 0.0f.xx.x, _6105.y > 0.0f.xx.y));
                bool _11750;
                if (_11744)
                {
                    _11750 = all(bool2(_6105.x < 1.0f.xx.x, _6105.y < 1.0f.xx.y));
                }
                else
                {
                    _11750 = _11744;
                }
                float3 _14976;
                if (_11750)
                {
                    float _6111 = abs(cbFI_DeviceToViewDepth.y / (_14138 - cbFI_DeviceToViewDepth.x));
                    uint _11770_dummy_parameter;
                    int2 _11770 = int2(spvTextureSize(r_depth_m2, uint(0), _11770_dummy_parameter));
                    float _6115 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6105 * float2(_11770))), int2(0, 0), _11770 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _14981;
                    if (abs(_6115 - _6111) <= (0.20000000298023223876953125f * max(_6115, _6111)))
                    {
                        uint _11804_dummy_parameter;
                        int2 _11804 = int2(spvTextureSize(r_colour_m2, uint(0), _11804_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _11827;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _11827);
                        }
                        _14981 = r_colour_m2.Load(int3(clamp(int2(floor(_6105 * float2(_11804))), int2(0, 0), _11804 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _11837;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _11837);
                        }
                        _14981 = _11651;
                    }
                    _14976 = _14981;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11847;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _11847);
                    }
                    _14976 = _11651;
                }
                _14975 = _14976;
            }
            else
            {
                _14975 = _11651;
            }
            _14973 = _14975;
        }
        else
        {
            _14973 = _14974;
        }
        uint _6143 = cbFI_pad0 & 255u;
        bool _14862;
        float3 _14972;
        if (_6143 != 0u)
        {
            float3 _6148 = r_present_backbuffer.Load(int3(_3998, 0)).xyz;
            float3 _6152 = r_current_interpolation_source.Load(int3(_3998, 0)).xyz;
            float3 _6156 = abs(_6148 - _6152);
            float3 _14142;
            if (_6143 == 2u)
            {
                _14142 = (abs(_6152) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _14142 = 0.000244140625f.xxx;
            }
            bool _6172 = any(bool3(_6156.x > _14142.x, _6156.y > _14142.y, _6156.z > _14142.z));
            bool3 _15210 = _6172.xxx;
            _14972 = float3(_15210.x ? _6148.x : _14973.x, _15210.y ? _6148.y : _14973.y, _15210.z ? _6148.z : _14973.z);
            _14862 = _6172;
        }
        else
        {
            _14972 = _14973;
            _14862 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _11862;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _11862);
        }
        float3 _14955;
        if (_5830 == 1u)
        {
            _14955 = lerp(_7372, _7380, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _14956;
            if (_5830 == 2u)
            {
                _14956 = lerp(_7388, _7396, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _14957;
                if (_5830 == 3u)
                {
                    _14957 = float(_14862).xxx;
                }
                else
                {
                    float3 _14958;
                    if (_5830 == 4u)
                    {
                        _14958 = float3(((_12586 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _14959;
                        if (_5830 == 5u)
                        {
                            _14959 = float3(((_6667 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _14960;
                            if (_5830 == 6u)
                            {
                                _14960 = float3(_13786.xy, _13786.z + _13786.w);
                            }
                            else
                            {
                                float3 _14961;
                                if (_5830 == 7u)
                                {
                                    _14961 = r_current_interpolation_source.Load(int3(_3998, 0)).xyz;
                                }
                                else
                                {
                                    float3 _14962;
                                    if (_5830 == 8u)
                                    {
                                        _14962 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4457, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _14963;
                                        if (_5834)
                                        {
                                            uint _11884_dummy_parameter;
                                            uint _11916_dummy_parameter;
                                            _14963 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4457 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11884_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4457 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11916_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _14964;
                                            if (_5837)
                                            {
                                                _14964 = _7388;
                                            }
                                            else
                                            {
                                                float3 _14965;
                                                if (_5830 == 20u)
                                                {
                                                    _14965 = _7372;
                                                }
                                                else
                                                {
                                                    float3 _14966;
                                                    if (_5830 == 21u)
                                                    {
                                                        _14966 = _7380;
                                                    }
                                                    else
                                                    {
                                                        float3 _14967;
                                                        if (_5830 == 22u)
                                                        {
                                                            _14967 = _7396;
                                                        }
                                                        else
                                                        {
                                                            float3 _14968;
                                                            if (_5830 == 18u)
                                                            {
                                                                _14968 = _14566;
                                                            }
                                                            else
                                                            {
                                                                float3 _14969;
                                                                if (_5830 == 19u)
                                                                {
                                                                    _14969 = _14354;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _15212 = (_5830 == 23u).xxx;
                                                                    _14969 = float3(_15212.x ? _14148.x : _14972.x, _15212.y ? _14148.y : _14972.y, _15212.z ? _14148.z : _14972.z);
                                                                }
                                                                _14968 = _14969;
                                                            }
                                                            _14967 = _14968;
                                                        }
                                                        _14966 = _14967;
                                                    }
                                                    _14965 = _14966;
                                                }
                                                _14964 = _14965;
                                            }
                                            _14963 = _14964;
                                        }
                                        _14962 = _14963;
                                    }
                                    _14961 = _14962;
                                }
                                _14960 = _14961;
                            }
                            _14959 = _14960;
                        }
                        _14958 = _14959;
                    }
                    _14957 = _14958;
                }
                _14956 = _14957;
            }
            _14955 = _14956;
        }
        float3 _14954;
        if ((_5830 >= 9u) && (_5830 <= 11u))
        {
            uint _6336 = 64u + uint((_12705.y * cbFI_MvDepthLaneSize.x) + _12705.x);
            uint _6340 = rw_nfru_diagnostics.Load<uint>(_6336 * 4 + 0) & 15u;
            float3 _14986;
            if (_5830 == 10u)
            {
                float3 _14953;
                if ((rw_nfru_diagnostics.Load<uint>(_6336 * 4 + 0) & 32u) != 0u)
                {
                    _14953 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _14952;
                    if ((rw_nfru_diagnostics.Load<uint>(_6336 * 4 + 0) & 16u) != 0u)
                    {
                        _14952 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6361 = ((rw_nfru_diagnostics.Load<uint>(_6336 * 4 + 0) & 64u) != 0u).xxx;
                        _14952 = float3(_6361.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6361.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6361.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _14953 = _14952;
                }
                _14986 = _14953;
            }
            else
            {
                float3 _14987;
                if (_5830 == 11u)
                {
                    uint _6374 = (rw_nfru_diagnostics.Load<uint>(_6336 * 4 + 0) >> 8u) & 15u;
                    uint _6377 = (rw_nfru_diagnostics.Load<uint>(_6336 * 4 + 0) >> 12u) & 15u;
                    float3 _14945;
                    if ((_6340 == 2u) || (_6340 == 3u))
                    {
                        _14945 = _3694[_6340];
                    }
                    else
                    {
                        bool _6389 = _6374 == 3u;
                        bool _6391 = _6377 == 3u;
                        float3 _14946;
                        if (_6389 && _6391)
                        {
                            _14946 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _14947;
                            if (_6389)
                            {
                                _14947 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _14948;
                                if (_6391)
                                {
                                    _14948 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _14949;
                                    if ((_6374 == 4u) || (_6377 == 4u))
                                    {
                                        _14949 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _14950;
                                        if ((_6374 == 1u) || (_6377 == 1u))
                                        {
                                            _14950 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _15214 = (_6340 == 1u).xxx;
                                            _14950 = float3(_15214.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _15214.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _15214.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _14949 = _14950;
                                    }
                                    _14948 = _14949;
                                }
                                _14947 = _14948;
                            }
                            _14946 = _14947;
                        }
                        _14945 = _14946;
                    }
                    _14987 = _14945;
                }
                else
                {
                    _14987 = _3694[min(_6340, 7u)];
                }
                _14986 = _14987;
            }
            _14954 = _14986;
        }
        else
        {
            _14954 = _14955;
        }
        float4 _14990;
        if ((_5830 >= 14u) && (_5830 <= 16u))
        {
            float2 _14988;
            if (_5830 == 14u)
            {
                uint _6447_dummy_parameter;
                uint _6453_dummy_parameter;
                _14988 = r_flow_tm1.Load(int3(clamp(int2(floor(_4457 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6447_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6453_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _14989;
                if (_5830 == 16u)
                {
                    uint _11967 = r_warped_flow_qdata_tm1.Load(int3(_4473, 0)).x & 2147483647u;
                    uint _11999 = uint(max((int((_11967 >> 16u) & 15u) - 6), 0));
                    _14989 = ((float2(float((1 - (2 * int((_11967 >> 15u) & 1u))) * int(((_11967 >> uint(7)) & 127u) << _11999)), float((1 - (2 * int((_11967 >> 14u) & 1u))) * int((_11967 & 127u) << _11999))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _14989 = _6667 * float2(cbFI_DisplaySize);
                }
                _14988 = _14989;
            }
            uint2 _6486 = uint2(clamp(round(_14988 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6488 = _6486.x;
            uint _6495 = _6486.y;
            _14990 = float4(float(_6488 & 255u), float((_6488 >> 8u) | ((_6495 & 15u) << 4u)), float(_6495 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _14991;
            if (_5830 == 17u)
            {
                _14991 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4473, 0)).x != 0u), _4917, 0.0f, 1.0f);
            }
            else
            {
                _14991 = float4(_14954, 1.0f);
            }
            _14990 = _14991;
        }
        rw_output[_3998] = _14990.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6539 = ((uint(_3998.y) * uint(cbFI_DisplaySize.x)) + uint(_3998.x)) * 6u;
            uint _12045 = spvPackHalf2x16(clamp(_7371.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6539 * 4 + 0, (((_12045 & 32767u) >> 4u) | ((((_12045 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7371.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12080 = spvPackHalf2x16(clamp(_7379.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6539 + 1u) * 4 + 0, (((_12080 & 32767u) >> 4u) | ((((_12080 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7379.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12115 = spvPackHalf2x16(clamp(_7387.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6539 + 2u) * 4 + 0, (((_12115 & 32767u) >> 4u) | ((((_12115 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7387.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12150 = spvPackHalf2x16(clamp(_7395.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6539 + 3u) * 4 + 0, (((_12150 & 32767u) >> 4u) | ((((_12150 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7395.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _12177 = r_current_interpolation_source.Load(int3(_3998, 0));
            uint _12191 = spvPackHalf2x16(clamp(_12177.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6539 + 4u) * 4 + 0, (((_12191 & 32767u) >> 4u) | ((((_12191 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12177.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _15024;
            if (_14862 || (_5830 != 0u))
            {
                _15024 = 4294967295u;
            }
            else
            {
                uint _12226 = spvPackHalf2x16(clamp(_14990.xy, 0.0f.xx, 65000.0f.xx));
                _15024 = (((_12226 & 32767u) >> 4u) | ((((_12226 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_14990.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6539 + 5u) * 4 + 0, _15024);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3998] = float4(r_current_interpolation_source.Load(int3(_3998, 0)).xyz, 1.0f).xyz;
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
