static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1098[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1107[5] = { 2, 4, 7, 11, 16 };
static const float3 _3695[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3999 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3999.x >= cbFI_DisplaySize.x, _3999.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3999] = float4(r_present_backbuffer.Load(int3(_3999, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3999] = float4(r_current_interpolation_source.Load(int3(_3999, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4458 = (float2(_3999) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4460 = float2(cbFI_MvDepthLaneSize);
        int2 _4469 = int2(floor(_4458 * _4460));
        int2 _4474 = int2(floor(_4458 * float2(cbFI_FlowLaneSize)));
        float4 _6662 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4458 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6668 = r_warped_filled_flow_tm1.Load(int3(_4474, 0)).xy;
        float2 _6674 = r_warped_filled_motion_tp1.Load(int3(_4469, 0)).xy;
        bool _6696 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _12574;
        if (_6696)
        {
            float _6709 = ((2.0f * _4458.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _12574 = float2(atan(_6709) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4458.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6709 * _6709))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _12574 = _4458;
        }
        bool _4495 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _12595;
        bool _12665;
        int2 _12714;
        float3 _14575;
        if (_4495)
        {
            float _12576;
            float _12578;
            _12578 = 2.0f;
            _12576 = -1.0f;
            uint _4068[9];
            float _15075;
            float _15078;
            for (int _12575 = 0; _12575 < 9; _12578 = _15078, _12576 = _15075, _12575++)
            {
                _4068[_12575] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4469 + int2((_12575 % 3) - 1, (_12575 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4068[_12575] != 0u)
                {
                    float _15070;
                    if (_4068[_12575] == 0u)
                    {
                        _15070 = -1.0f;
                    }
                    else
                    {
                        _15070 = float((_4068[_12575] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _15078 = min(_12578, _15070);
                    _15075 = max(_12576, _15070);
                }
                else
                {
                    _15078 = _12578;
                    _15075 = _12576;
                }
            }
            float _4541 = float(_12576 >= 0.0f);
            float3 _12277 = 0.0f.xxx;
            _12277.y = _4541;
            float2 _12596;
            bool _12666;
            int2 _12715;
            float3 _14576;
            if ((_12576 - _12578) > 0.0199999995529651641845703125f)
            {
                float _12584;
                int2 _12585;
                float2 _12586;
                int2 _12588;
                float2 _12594;
                _12594 = _6674;
                _12588 = _4469;
                _12586 = _6674;
                _12585 = _4469;
                _12584 = -1.0f;
                float _15083;
                int2 _15087;
                float2 _15098;
                int2 _15109;
                float2 _15142;
                float _15189;
                int _12583 = 0;
                float _15051 = 1000000000.0f;
                for (; _12583 < 9; _15051 = _15189, _12594 = _15142, _12588 = _15109, _12586 = _15098, _12585 = _15087, _12584 = _15083, _12583++)
                {
                    if (_4068[_12583] == 0u)
                    {
                        _15189 = _15051;
                        _15142 = _12594;
                        _15109 = _12588;
                        _15098 = _12586;
                        _15087 = _12585;
                        _15083 = _12584;
                        continue;
                    }
                    int2 _4576 = clamp(_4469 + int2((_12583 % 3) - 1, (_12583 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6784 = _4068[_12583] & 2147483647u;
                    uint _6816 = uint(max((int((_6784 >> 16u) & 15u) - 6), 0));
                    float2 _4582 = (float2(float((1 - (2 * int((_6784 >> 15u) & 1u))) * int(((_6784 >> uint(7)) & 127u) << _6816)), float((1 - (2 * int((_6784 >> 14u) & 1u))) * int((_6784 & 127u) << _6816))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _15037;
                    if (_4068[_12583] == 0u)
                    {
                        _15037 = -1.0f;
                    }
                    else
                    {
                        _15037 = float((_4068[_12583] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4587 = _15037 - 0.100000001490116119384765625f;
                    float2 _15038;
                    if (_6696)
                    {
                        float2 _6893 = clamp((((_12574 + (_4582 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6896 = tan(_6893.x);
                        _15038 = (float2(_6896 / cbFI_DeviceToViewDepth.z, (tan(_6893.y) * sqrt(1.0f + (_6896 * _6896))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _15038 = _12574 + (_4582 * cbFI_Timestep);
                    }
                    float _4594 = cbFI_Timestep - 1.0f;
                    float2 _15039;
                    if (_6696)
                    {
                        float2 _6964 = clamp((((_12574 + (_4582 * _4594)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6967 = tan(_6964.x);
                        _15039 = (float2(_6967 / cbFI_DeviceToViewDepth.z, (tan(_6964.y) * sqrt(1.0f + (_6967 * _6967))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _15039 = _12574 + (_4582 * _4594);
                    }
                    bool _7000 = all(bool2(_15038.x > 0.0f.xx.x, _15038.y > 0.0f.xx.y));
                    bool _7006;
                    if (_7000)
                    {
                        _7006 = all(bool2(_15038.x < 1.0f.xx.x, _15038.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7006 = _7000;
                    }
                    float _15042;
                    if (_7006)
                    {
                        uint _7013_dummy_parameter;
                        _15042 = max((_4587 - (log(((r_depth_tm1.Load(int3(int2(floor(_15038 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7013_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _15042 = 0.0f;
                    }
                    bool _7043 = all(bool2(_15039.x > 0.0f.xx.x, _15039.y > 0.0f.xx.y));
                    bool _7049;
                    if (_7043)
                    {
                        _7049 = all(bool2(_15039.x < 1.0f.xx.x, _15039.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7049 = _7043;
                    }
                    float _15043;
                    if (_7049)
                    {
                        uint _7056_dummy_parameter;
                        _15043 = _15042 + max((_4587 - (log(((r_depth_tp1.Load(int3(int2(floor(_15039 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7056_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _15043 = _15042;
                    }
                    float _15084;
                    int2 _15088;
                    float2 _15099;
                    int2 _15110;
                    float2 _15143;
                    float _15190;
                    if (_15043 == 0.0f)
                    {
                        bool _4629 = _4587 > _12584;
                        bool2 _15198 = _4629.xx;
                        _15190 = _15051;
                        _15143 = float2(_15198.x ? _4582.x : _12594.x, _15198.y ? _4582.y : _12594.y);
                        _15110 = int2(_15198.x ? _4576.x : _12588.x, _15198.y ? _4576.y : _12588.y);
                        _15099 = _12586;
                        _15088 = _12585;
                        _15084 = _4629 ? _4587 : _12584;
                    }
                    else
                    {
                        bool _4638 = _15043 < _15051;
                        bool2 _15194 = _4638.xx;
                        _15190 = _4638 ? _15043 : _15051;
                        _15143 = _12594;
                        _15110 = _12588;
                        _15099 = float2(_15194.x ? _4582.x : _12586.x, _15194.y ? _4582.y : _12586.y);
                        _15088 = int2(_15194.x ? _4576.x : _12585.x, _15194.y ? _4576.y : _12585.y);
                        _15084 = _12584;
                    }
                    _15189 = _15190;
                    _15142 = _15143;
                    _15109 = _15110;
                    _15098 = _15099;
                    _15087 = _15088;
                    _15083 = _15084;
                }
                bool _4650 = _12584 < 0.0f;
                bool2 _15204 = _4650.xx;
                int2 _15207 = int2(_15204.x ? _12585.x : _12588.x, _15204.y ? _12585.y : _12588.y);
                _14576 = float3(1.0f, _4541, float(any(bool2(_15207.x != _4469.x, _15207.y != _4469.y))));
                _12715 = _15207;
                _12666 = _4650 ? false : true;
                _12596 = float2(_15204.x ? _12586.x : _12594.x, _15204.y ? _12586.y : _12594.y);
            }
            else
            {
                _14576 = _12277;
                _12715 = _4469;
                _12666 = false;
                _12596 = _6674;
            }
            _14575 = _14576;
            _12714 = _12715;
            _12665 = _12666;
            _12595 = _12596;
        }
        else
        {
            _14575 = 0.0f.xxx;
            _12714 = _4469;
            _12665 = false;
            _12595 = _6674;
        }
        float2 _12597;
        if (_6696)
        {
            float2 _7121 = clamp((((_12574 + (_12595 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7124 = tan(_7121.x);
            _12597 = (float2(_7124 / cbFI_DeviceToViewDepth.z, (tan(_7121.y) * sqrt(1.0f + (_7124 * _7124))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12597 = _12574 + (_12595 * cbFI_Timestep);
        }
        float _4673 = cbFI_Timestep - 1.0f;
        float2 _12599;
        if (_6696)
        {
            float2 _7192 = clamp((((_12574 + (_12595 * _4673)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7195 = tan(_7192.x);
            _12599 = (float2(_7195 / cbFI_DeviceToViewDepth.z, (tan(_7192.y) * sqrt(1.0f + (_7195 * _7195))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12599 = _12574 + (_12595 * _4673);
        }
        float _4678 = -cbFI_Timestep;
        float2 _12600;
        if (_6696)
        {
            float2 _7263 = clamp((((_12574 + (_6668 * _4678)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7266 = tan(_7263.x);
            _12600 = (float2(_7266 / cbFI_DeviceToViewDepth.z, (tan(_7263.y) * sqrt(1.0f + (_7266 * _7266))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12600 = _12574 + (_6668 * _4678);
        }
        float _4683 = 1.0f - cbFI_Timestep;
        float2 _12601;
        if (_6696)
        {
            float2 _7334 = clamp((((_12574 + (_6668 * _4683)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7337 = tan(_7334.x);
            _12601 = (float2(_7337 / cbFI_DeviceToViewDepth.z, (tan(_7334.y) * sqrt(1.0f + (_7337 * _7337))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12601 = _12574 + (_6668 * _4683);
        }
        float4 _7372 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _12597, 0.0f);
        float3 _7373 = _7372.xyz;
        float4 _7380 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _12599, 0.0f);
        float3 _7381 = _7380.xyz;
        float4 _7388 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _12600, 0.0f);
        float3 _7389 = _7388.xyz;
        float4 _7396 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _12601, 0.0f);
        float3 _7397 = _7396.xyz;
        float4 _7411 = exp(_6662 - max(max(max(_6662.x, _6662.y), _6662.z), _6662.w).xxxx);
        float4 _7418 = _7411 / (dot(_7411, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4699 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _12704;
        float _13810;
        if (_4699)
        {
            float2 _4705 = 0.5f.xx / _4460;
            float _4708 = _4705.x;
            float _4709 = -_4708;
            float _4711 = _4705.y;
            float _4712 = -_4711;
            float2 _4714 = _4458 + float2(_4709, _4712);
            float2 _4716 = float2(cbFI_DisplaySize);
            bool _12613;
            do
            {
                bool _7498 = all(bool2(_4714.x > 0.0f.xx.x, _4714.y > 0.0f.xx.y));
                bool _7504;
                if (_7498)
                {
                    _7504 = all(bool2(_4714.x < 1.0f.xx.x, _4714.y < 1.0f.xx.y));
                }
                else
                {
                    _7504 = _7498;
                }
                if (!_7504)
                {
                    _12613 = false;
                    break;
                }
                uint _7511_dummy_parameter;
                float2 _12612;
                do
                {
                    float _7534 = _4714.x;
                    float _7537 = 1.0f - _4714.y;
                    float4 _7548 = mul(float4((float2(_7534, _7537) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4714 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7511_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7550 = _7548.w;
                    if (!(_7550 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12612 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7563 = ((_7548.xy / _7550.xx) + 1.0f.xx) * 0.5f;
                    _12612 = float2(_7563.x - _7534, _7537 - _7563.y);
                    break;
                } while(false);
                float2 _7462 = abs(_12612);
                if (any(bool2(_7462.x > 100000.0f.xx.x, _7462.y > 100000.0f.xx.y)))
                {
                    _12613 = false;
                    break;
                }
                float _7470 = length(_12612 * _4716);
                uint _7583_dummy_parameter;
                bool _7484 = _7470 > ((8.0f * _4716.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7491;
                if (_7484)
                {
                    _7491 = length((r_motion_tp1.Load(int3(int2(floor(_4714 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7583_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4716) < (0.20000000298023223876953125f * _7470);
                }
                else
                {
                    _7491 = _7484;
                }
                _12613 = _7491;
                break;
            } while(false);
            float2 _4726 = _4458 + float2(_4708, _4712);
            bool _12615;
            do
            {
                bool _7669 = all(bool2(_4726.x > 0.0f.xx.x, _4726.y > 0.0f.xx.y));
                bool _7675;
                if (_7669)
                {
                    _7675 = all(bool2(_4726.x < 1.0f.xx.x, _4726.y < 1.0f.xx.y));
                }
                else
                {
                    _7675 = _7669;
                }
                if (!_7675)
                {
                    _12615 = false;
                    break;
                }
                uint _7682_dummy_parameter;
                float2 _12614;
                do
                {
                    float _7705 = _4726.x;
                    float _7708 = 1.0f - _4726.y;
                    float4 _7719 = mul(float4((float2(_7705, _7708) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4726 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7682_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7721 = _7719.w;
                    if (!(_7721 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12614 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7734 = ((_7719.xy / _7721.xx) + 1.0f.xx) * 0.5f;
                    _12614 = float2(_7734.x - _7705, _7708 - _7734.y);
                    break;
                } while(false);
                float2 _7633 = abs(_12614);
                if (any(bool2(_7633.x > 100000.0f.xx.x, _7633.y > 100000.0f.xx.y)))
                {
                    _12615 = false;
                    break;
                }
                float _7641 = length(_12614 * _4716);
                uint _7754_dummy_parameter;
                bool _7655 = _7641 > ((8.0f * _4716.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7662;
                if (_7655)
                {
                    _7662 = length((r_motion_tp1.Load(int3(int2(floor(_4726 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7754_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4716) < (0.20000000298023223876953125f * _7641);
                }
                else
                {
                    _7662 = _7655;
                }
                _12615 = _7662;
                break;
            } while(false);
            float2 _4739 = _4458 + float2(_4709, _4711);
            bool _12617;
            do
            {
                bool _7840 = all(bool2(_4739.x > 0.0f.xx.x, _4739.y > 0.0f.xx.y));
                bool _7846;
                if (_7840)
                {
                    _7846 = all(bool2(_4739.x < 1.0f.xx.x, _4739.y < 1.0f.xx.y));
                }
                else
                {
                    _7846 = _7840;
                }
                if (!_7846)
                {
                    _12617 = false;
                    break;
                }
                uint _7853_dummy_parameter;
                float2 _12616;
                do
                {
                    float _7876 = _4739.x;
                    float _7879 = 1.0f - _4739.y;
                    float4 _7890 = mul(float4((float2(_7876, _7879) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4739 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7853_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7892 = _7890.w;
                    if (!(_7892 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12616 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7905 = ((_7890.xy / _7892.xx) + 1.0f.xx) * 0.5f;
                    _12616 = float2(_7905.x - _7876, _7879 - _7905.y);
                    break;
                } while(false);
                float2 _7804 = abs(_12616);
                if (any(bool2(_7804.x > 100000.0f.xx.x, _7804.y > 100000.0f.xx.y)))
                {
                    _12617 = false;
                    break;
                }
                float _7812 = length(_12616 * _4716);
                uint _7925_dummy_parameter;
                bool _7826 = _7812 > ((8.0f * _4716.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7833;
                if (_7826)
                {
                    _7833 = length((r_motion_tp1.Load(int3(int2(floor(_4739 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7925_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4716) < (0.20000000298023223876953125f * _7812);
                }
                else
                {
                    _7833 = _7826;
                }
                _12617 = _7833;
                break;
            } while(false);
            float2 _4751 = _4458 + _4705;
            bool _12619;
            do
            {
                bool _8011 = all(bool2(_4751.x > 0.0f.xx.x, _4751.y > 0.0f.xx.y));
                bool _8017;
                if (_8011)
                {
                    _8017 = all(bool2(_4751.x < 1.0f.xx.x, _4751.y < 1.0f.xx.y));
                }
                else
                {
                    _8017 = _8011;
                }
                if (!_8017)
                {
                    _12619 = false;
                    break;
                }
                uint _8024_dummy_parameter;
                float2 _12618;
                do
                {
                    float _8047 = _4751.x;
                    float _8050 = 1.0f - _4751.y;
                    float4 _8061 = mul(float4((float2(_8047, _8050) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4751 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8024_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _8063 = _8061.w;
                    if (!(_8063 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12618 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8076 = ((_8061.xy / _8063.xx) + 1.0f.xx) * 0.5f;
                    _12618 = float2(_8076.x - _8047, _8050 - _8076.y);
                    break;
                } while(false);
                float2 _7975 = abs(_12618);
                if (any(bool2(_7975.x > 100000.0f.xx.x, _7975.y > 100000.0f.xx.y)))
                {
                    _12619 = false;
                    break;
                }
                float _7983 = length(_12618 * _4716);
                uint _8096_dummy_parameter;
                bool _7997 = _7983 > ((8.0f * _4716.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8004;
                if (_7997)
                {
                    _8004 = length((r_motion_tp1.Load(int3(int2(floor(_4751 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8096_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4716) < (0.20000000298023223876953125f * _7983);
                }
                else
                {
                    _8004 = _7997;
                }
                _12619 = _8004;
                break;
            } while(false);
            float _4757 = 0.25f * (((float(_12613) + float(_12615)) + float(_12617)) + float(_12619));
            float4 _12705;
            if (_4757 < 1.0f)
            {
                bool _12621;
                do
                {
                    bool _8182 = all(bool2(_12597.x > 0.0f.xx.x, _12597.y > 0.0f.xx.y));
                    bool _8188;
                    if (_8182)
                    {
                        _8188 = all(bool2(_12597.x < 1.0f.xx.x, _12597.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8188 = _8182;
                    }
                    if (!_8188)
                    {
                        _12621 = false;
                        break;
                    }
                    uint _8195_dummy_parameter;
                    float2 _12620;
                    do
                    {
                        float _8221 = 1.0f - _12597.y;
                        float4 _8232 = mul(float4((float2(_12597.x, _8221) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12597 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8195_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8234 = _8232.w;
                        if (!(_8234 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12620 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8247 = ((_8232.xy / _8234.xx) + 1.0f.xx) * 0.5f;
                        _12620 = float2(_8247.x - _12597.x, _8221 - _8247.y);
                        break;
                    } while(false);
                    float2 _8146 = abs(_12620);
                    if (any(bool2(_8146.x > 100000.0f.xx.x, _8146.y > 100000.0f.xx.y)))
                    {
                        _12621 = false;
                        break;
                    }
                    float _8154 = length(_12620 * _4716);
                    uint _8267_dummy_parameter;
                    bool _8168 = _8154 > ((8.0f * _4716.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8175;
                    if (_8168)
                    {
                        _8175 = length((r_motion_tp1.Load(int3(int2(floor(_12597 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8267_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4716) < (0.20000000298023223876953125f * _8154);
                    }
                    else
                    {
                        _8175 = _8168;
                    }
                    _12621 = _8175;
                    break;
                } while(false);
                bool _12623;
                do
                {
                    bool _8353 = all(bool2(_12599.x > 0.0f.xx.x, _12599.y > 0.0f.xx.y));
                    bool _8359;
                    if (_8353)
                    {
                        _8359 = all(bool2(_12599.x < 1.0f.xx.x, _12599.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8359 = _8353;
                    }
                    if (!_8359)
                    {
                        _12623 = false;
                        break;
                    }
                    uint _8366_dummy_parameter;
                    float2 _12622;
                    do
                    {
                        float _8392 = 1.0f - _12599.y;
                        float4 _8403 = mul(float4((float2(_12599.x, _8392) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12599 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8366_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8405 = _8403.w;
                        if (!(_8405 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12622 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8418 = ((_8403.xy / _8405.xx) + 1.0f.xx) * 0.5f;
                        _12622 = float2(_8418.x - _12599.x, _8392 - _8418.y);
                        break;
                    } while(false);
                    float2 _8317 = abs(_12622);
                    if (any(bool2(_8317.x > 100000.0f.xx.x, _8317.y > 100000.0f.xx.y)))
                    {
                        _12623 = false;
                        break;
                    }
                    float _8325 = length(_12622 * _4716);
                    uint _8438_dummy_parameter;
                    bool _8339 = _8325 > ((8.0f * _4716.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8346;
                    if (_8339)
                    {
                        _8346 = length((r_motion_tp1.Load(int3(int2(floor(_12599 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8438_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4716) < (0.20000000298023223876953125f * _8325);
                    }
                    else
                    {
                        _8346 = _8339;
                    }
                    _12623 = _8346;
                    break;
                } while(false);
                bool _12625;
                do
                {
                    bool _8524 = all(bool2(_12600.x > 0.0f.xx.x, _12600.y > 0.0f.xx.y));
                    bool _8530;
                    if (_8524)
                    {
                        _8530 = all(bool2(_12600.x < 1.0f.xx.x, _12600.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8530 = _8524;
                    }
                    if (!_8530)
                    {
                        _12625 = false;
                        break;
                    }
                    uint _8537_dummy_parameter;
                    float2 _12624;
                    do
                    {
                        float _8563 = 1.0f - _12600.y;
                        float4 _8574 = mul(float4((float2(_12600.x, _8563) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12600 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8537_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8576 = _8574.w;
                        if (!(_8576 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12624 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8589 = ((_8574.xy / _8576.xx) + 1.0f.xx) * 0.5f;
                        _12624 = float2(_8589.x - _12600.x, _8563 - _8589.y);
                        break;
                    } while(false);
                    float2 _8488 = abs(_12624);
                    if (any(bool2(_8488.x > 100000.0f.xx.x, _8488.y > 100000.0f.xx.y)))
                    {
                        _12625 = false;
                        break;
                    }
                    float _8496 = length(_12624 * _4716);
                    uint _8609_dummy_parameter;
                    bool _8510 = _8496 > ((8.0f * _4716.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8517;
                    if (_8510)
                    {
                        _8517 = length((r_motion_tp1.Load(int3(int2(floor(_12600 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8609_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4716) < (0.20000000298023223876953125f * _8496);
                    }
                    else
                    {
                        _8517 = _8510;
                    }
                    _12625 = _8517;
                    break;
                } while(false);
                bool _12627;
                do
                {
                    bool _8695 = all(bool2(_12601.x > 0.0f.xx.x, _12601.y > 0.0f.xx.y));
                    bool _8701;
                    if (_8695)
                    {
                        _8701 = all(bool2(_12601.x < 1.0f.xx.x, _12601.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8701 = _8695;
                    }
                    if (!_8701)
                    {
                        _12627 = false;
                        break;
                    }
                    uint _8708_dummy_parameter;
                    float2 _12626;
                    do
                    {
                        float _8734 = 1.0f - _12601.y;
                        float4 _8745 = mul(float4((float2(_12601.x, _8734) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12601 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8708_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8747 = _8745.w;
                        if (!(_8747 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12626 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8760 = ((_8745.xy / _8747.xx) + 1.0f.xx) * 0.5f;
                        _12626 = float2(_8760.x - _12601.x, _8734 - _8760.y);
                        break;
                    } while(false);
                    float2 _8659 = abs(_12626);
                    if (any(bool2(_8659.x > 100000.0f.xx.x, _8659.y > 100000.0f.xx.y)))
                    {
                        _12627 = false;
                        break;
                    }
                    float _8667 = length(_12626 * _4716);
                    uint _8780_dummy_parameter;
                    bool _8681 = _8667 > ((8.0f * _4716.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8688;
                    if (_8681)
                    {
                        _8688 = length((r_motion_tp1.Load(int3(int2(floor(_12601 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8780_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4716) < (0.20000000298023223876953125f * _8667);
                    }
                    else
                    {
                        _8688 = _8681;
                    }
                    _12627 = _8688;
                    break;
                } while(false);
                float4 _4784 = _7418 * float4(_12621 ? 0.0f : 1.0f, _12623 ? 0.0f : 1.0f, _12625 ? 0.0f : 1.0f, _12627 ? 0.0f : 1.0f);
                float _4786 = dot(_4784, 1.0f.xxxx);
                float4 _12706;
                if (_4786 > 0.001000000047497451305389404296875f)
                {
                    _12706 = _4784 / _4786.xxxx;
                }
                else
                {
                    _12706 = _7418;
                }
                _12705 = _12706;
            }
            else
            {
                _12705 = _7418;
            }
            _13810 = _4757;
            _12704 = _12705;
        }
        else
        {
            _13810 = 0.0f;
            _12704 = _7418;
        }
        bool _4803 = _4495 && (!_12665);
        bool _4812;
        if (_4803)
        {
            _4812 = (_12704.z + _12704.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4812 = _4803;
        }
        bool _4823;
        if (_4812)
        {
            _4823 = length((_12600 - _12597) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4823 = _4812;
        }
        bool _12761;
        if (_4823)
        {
            uint4 _8809 = r_warped_motion_qdata_tp1.Load(int3(_12714, 0));
            uint _8810 = _8809.x;
            bool _12764;
            if (_8810 != 0u)
            {
                float _12750;
                if (_8810 == 0u)
                {
                    _12750 = -1.0f;
                }
                else
                {
                    _12750 = float((_8810 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4833 = _12750 - 0.12000000476837158203125f;
                bool _8829 = all(bool2(_12600.x > 0.0f.xx.x, _12600.y > 0.0f.xx.y));
                bool _8835;
                if (_8829)
                {
                    _8835 = all(bool2(_12600.x < 1.0f.xx.x, _12600.y < 1.0f.xx.y));
                }
                else
                {
                    _8835 = _8829;
                }
                bool _4843;
                if (_8835)
                {
                    uint _8842_dummy_parameter;
                    _4843 = (log(((r_depth_tm1.Load(int3(int2(floor(_12600 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8842_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4833;
                }
                else
                {
                    _4843 = _8835;
                }
                bool _4857;
                if (!_4843)
                {
                    bool _8872 = all(bool2(_12601.x > 0.0f.xx.x, _12601.y > 0.0f.xx.y));
                    bool _8878;
                    if (_8872)
                    {
                        _8878 = all(bool2(_12601.x < 1.0f.xx.x, _12601.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8878 = _8872;
                    }
                    bool _4855;
                    if (_8878)
                    {
                        uint _8885_dummy_parameter;
                        _4855 = (log(((r_depth_tp1.Load(int3(int2(floor(_12601 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8885_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4833;
                    }
                    else
                    {
                        _4855 = _8878;
                    }
                    _4857 = _4855;
                }
                else
                {
                    _4857 = _4843;
                }
                _12764 = _4857;
            }
            else
            {
                _12764 = false;
            }
            _12761 = _12764;
        }
        else
        {
            _12761 = false;
        }
        bool _4862 = _12665 || _12761;
        bool _4867;
        if (_4862)
        {
            bool _8915 = all(bool2(_12597.x > 0.0f.xx.x, _12597.y > 0.0f.xx.y));
            bool _8921;
            if (_8915)
            {
                _8921 = all(bool2(_12597.x < 1.0f.xx.x, _12597.y < 1.0f.xx.y));
            }
            else
            {
                _8921 = _8915;
            }
            _4867 = _8921;
        }
        else
        {
            _4867 = _4862;
        }
        bool _4872;
        if (_4867)
        {
            bool _8926 = all(bool2(_12599.x > 0.0f.xx.x, _12599.y > 0.0f.xx.y));
            bool _8932;
            if (_8926)
            {
                _8932 = all(bool2(_12599.x < 1.0f.xx.x, _12599.y < 1.0f.xx.y));
            }
            else
            {
                _8932 = _8926;
            }
            _4872 = _8932;
        }
        else
        {
            _4872 = _4867;
        }
        float4 _12858;
        if (_4872)
        {
            float _4878 = _12704.x + _12704.y;
            float _4883 = _12704.z + _12704.w;
            float _12779;
            if (_4878 > 0.001000000047497451305389404296875f)
            {
                _12779 = _12704.x / _4878;
            }
            else
            {
                _12779 = _4683;
            }
            _12858 = float4(_12704.x + (_4883 * _12779), _12704.y + (_4883 * (1.0f - _12779)), 0.0f, 0.0f);
        }
        else
        {
            _12858 = _12704;
        }
        bool _8960 = (cbFI_pad0 & 1024u) != 0u;
        bool _8936 = !_8960;
        bool _8937 = !_8936;
        bool _8954;
        if (_8937)
        {
            _8954 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_12714.y * cbFI_MvDepthLaneSize.x) + _12714.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _8954 = _8936;
        }
        bool _8986;
        if (_8937)
        {
            _8986 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4474.y * cbFI_FlowLaneSize.x) + _4474.x)) * 4 + 0) != 0u;
        }
        else
        {
            _8986 = _8936;
        }
        float _4918 = float(_8986);
        bool _12871;
        float4 _12902;
        float3 _14363;
        if (_8960)
        {
            bool _4928;
            if (_8954)
            {
                _4928 = all(bool2(_12597.x > 0.0f.xx.x, _12597.y > 0.0f.xx.y));
            }
            else
            {
                _4928 = _8954;
            }
            bool _4934;
            if (_4928)
            {
                _4934 = all(bool2(_12597.x < 1.0f.xx.x, _12597.y < 1.0f.xx.y));
            }
            else
            {
                _4934 = _4928;
            }
            bool _4941;
            if (_8954)
            {
                _4941 = all(bool2(_12599.x > 0.0f.xx.x, _12599.y > 0.0f.xx.y));
            }
            else
            {
                _4941 = _8954;
            }
            bool _4947;
            if (_4941)
            {
                _4947 = all(bool2(_12599.x < 1.0f.xx.x, _12599.y < 1.0f.xx.y));
            }
            else
            {
                _4947 = _4941;
            }
            bool _4954;
            if (_8986)
            {
                _4954 = all(bool2(_12600.x > 0.0f.xx.x, _12600.y > 0.0f.xx.y));
            }
            else
            {
                _4954 = _8986;
            }
            bool _4960;
            if (_4954)
            {
                _4960 = all(bool2(_12600.x < 1.0f.xx.x, _12600.y < 1.0f.xx.y));
            }
            else
            {
                _4960 = _4954;
            }
            bool _4967;
            if (_8986)
            {
                _4967 = all(bool2(_12601.x > 0.0f.xx.x, _12601.y > 0.0f.xx.y));
            }
            else
            {
                _4967 = _8986;
            }
            bool _4973;
            if (_4967)
            {
                _4973 = all(bool2(_12601.x < 1.0f.xx.x, _12601.y < 1.0f.xx.y));
            }
            else
            {
                _4973 = _4967;
            }
            bool _4975 = !_8954;
            if (_4975)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9028;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _9028);
                }
            }
            bool _4980 = !_8986;
            if (_4980)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9038;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _9038);
                }
            }
            if (_8954 && _4980)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9048;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _9048);
                }
            }
            if (_4975 && _8986)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9058;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _9058);
                }
            }
            float _4999 = float(_4934);
            float _5001 = float(_4947);
            bool _5004 = _4960 && _4973;
            float _12813;
            if (_5004)
            {
                _12813 = 1.0f;
            }
            else
            {
                _12813 = (_4960 || _4973) ? 0.5f : 0.0f;
            }
            bool _12818;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4934)) && (!_4947))
            {
                bool _5034;
                if (_5004)
                {
                    float _12816;
                    do
                    {
                        bool _9142 = all(bool2(_12600.x > 0.0f.xx.x, _12600.y > 0.0f.xx.y));
                        bool _9148;
                        if (_9142)
                        {
                            _9148 = all(bool2(_12600.x < 1.0f.xx.x, _12600.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _9148 = _9142;
                        }
                        bool _9079 = !_9148;
                        bool _9086;
                        if (!_9079)
                        {
                            bool _9153 = all(bool2(_12601.x > 0.0f.xx.x, _12601.y > 0.0f.xx.y));
                            bool _9159;
                            if (_9153)
                            {
                                _9159 = all(bool2(_12601.x < 1.0f.xx.x, _12601.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _9159 = _9153;
                            }
                            _9086 = !_9159;
                        }
                        else
                        {
                            _9086 = _9079;
                        }
                        if (_9086)
                        {
                            _12816 = 0.0f;
                            break;
                        }
                        uint _9166_dummy_parameter;
                        uint _9182_dummy_parameter;
                        float4 _9107 = mul(float4((float2(_12600.x, 1.0f - _12600.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12600 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9166_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _9109 = _9107.w;
                        if (abs(_9109) < 9.9999999747524270787835121154785e-07f)
                        {
                            _12816 = 0.0f;
                            break;
                        }
                        float _9120 = abs(cbFI_DeviceToViewDepth.y / ((_9107.z / _9109) - cbFI_DeviceToViewDepth.x));
                        float _9123 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12601 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9182_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _12816 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9120 - _9123) / max(max(_9120, _9123), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5034 = _12816 >= 0.5f;
                }
                else
                {
                    _5034 = _5004;
                }
                bool _5042;
                if (_5034)
                {
                    _5042 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5042 = _5034;
                }
                bool _12819;
                if (_5042)
                {
                    uint _9232_dummy_parameter;
                    float2 _12817;
                    do
                    {
                        float _9258 = 1.0f - _12600.y;
                        float4 _9269 = mul(float4((float2(_12600.x, _9258) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12600 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9232_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _9271 = _9269.w;
                        if (!(_9271 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12817 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9284 = ((_9269.xy / _9271.xx) + 1.0f.xx) * 0.5f;
                        _12817 = float2(_9284.x - _12600.x, _9258 - _9284.y);
                        break;
                    } while(false);
                    float2 _5055 = float2(cbFI_DisplaySize);
                    _12819 = length(((_12600 + _12817) - _12601) * _5055) <= ((0.100000001490116119384765625f * length(_12817 * _5055)) + 8.0f);
                }
                else
                {
                    _12819 = _5034;
                }
                _12818 = _12819;
            }
            else
            {
                _12818 = true;
            }
            bool _5069 = !_12818;
            bool _15208 = _5069 ? false : _4973;
            bool _15209 = _5069 ? false : _4960;
            bool _12872;
            float4 _12903;
            if (!(((_4934 && _4947) && _15209) && _15208))
            {
                float4 _5091 = _12858 * float4(_4999, _5001, float(_15209), float(_15208));
                float _5093 = dot(_5091, 1.0f.xxxx);
                bool _5096 = !(_5093 > 0.0f);
                float4 _12904;
                if (!_5096)
                {
                    _12904 = _5091 / _5093.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9306;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9306);
                    }
                    _12904 = 0.0f.xxxx;
                }
                _12903 = _12904;
                _12872 = _5096;
            }
            else
            {
                _12903 = _12858;
                _12872 = false;
            }
            _14363 = float3(_4999, _5001, _12813);
            _12902 = _12903;
            _12871 = _12872;
        }
        else
        {
            _14363 = float3(float(_8954), _4918, 0.0f);
            _12902 = _12858;
            _12871 = false;
        }
        bool _5114 = !_12871;
        float4 _12987;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5114)
        {
            float _5121 = _12902.x + _12902.y;
            float4 _12988;
            if (_5121 > 0.001000000047497451305389404296875f)
            {
                _12988 = float4(_12902.x / _5121, _12902.y / _5121, 0.0f, 0.0f);
            }
            else
            {
                _12988 = float4(_4683, cbFI_Timestep, 0.0f, 0.0f);
            }
            _12987 = _12988;
        }
        else
        {
            _12987 = _12902;
        }
        float4 _13164;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5114) && _8954)
        {
            float _12961;
            do
            {
                uint4 _9446 = r_warped_motion_qdata_tp1.Load(int3(_12714, 0));
                uint _9447 = _9446.x;
                if (_9447 != 0u)
                {
                    float _12960;
                    if (_9447 == 0u)
                    {
                        _12960 = -1.0f;
                    }
                    else
                    {
                        _12960 = float((_9447 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12961 = _12960;
                    break;
                }
                int _12943;
                uint _12944;
                _12944 = _9447;
                _12943 = -1;
                uint _12959;
                for (; _12943 <= 1; _12944 = _12959, _12943++)
                {
                    _12959 = _12944;
                    for (int _12957 = -1; _12957 <= 1; )
                    {
                        _12959 = max(_12959, r_warped_motion_qdata_tp1.Load(int3(clamp(_12714 + int2(_12957, _12943), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _12957++;
                        continue;
                    }
                }
                if (_12944 != 0u)
                {
                    float _12956;
                    if (_12944 == 0u)
                    {
                        _12956 = -1.0f;
                    }
                    else
                    {
                        _12956 = float((_12944 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12961 = _12956;
                    break;
                }
                uint _12946;
                _12946 = 4294967295u;
                uint _15179;
                for (int _12945 = 0; _12945 < 8; _12946 = _15179, _12945++)
                {
                    int _12949 = 0;
                    for (;;)
                    {
                        if (_12949 < 5)
                        {
                            int2 _9397 = _12714 + (_1098[_12945] * _1107[_12949].xx);
                            bool _9400 = any(bool2(_9397.x < int2(0, 0).x, _9397.y < int2(0, 0).y));
                            bool _9408;
                            if (!_9400)
                            {
                                _9408 = any(bool2(_9397.x >= cbFI_MvDepthLaneSize.x, _9397.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _9408 = _9400;
                            }
                            if (_9408)
                            {
                                _15179 = _12946;
                                break;
                            }
                            uint4 _9486 = r_warped_motion_qdata_tp1.Load(int3(_9397, 0));
                            uint _9487 = _9486.x;
                            if (_9487 != 0u)
                            {
                                _15179 = min(_12946, _9487);
                                break;
                            }
                            _12949++;
                            continue;
                        }
                        else
                        {
                            _15179 = _12946;
                            break;
                        }
                    }
                }
                float _12948;
                if (_12946 == 4294967295u)
                {
                    _12948 = -1.0f;
                }
                else
                {
                    float _12947;
                    if (_12946 == 0u)
                    {
                        _12947 = -1.0f;
                    }
                    else
                    {
                        _12947 = float((_12946 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12948 = _12947;
                }
                _12961 = _12948;
                break;
            } while(false);
            float _5157 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5160 = r_warped_motion_qdata_tp1.Load(int3(_12714, 0)).x == 0u;
            bool _5166;
            if (_5160)
            {
                bool _9512 = all(bool2(_12597.x > 0.0f.xx.x, _12597.y > 0.0f.xx.y));
                bool _9518;
                if (_9512)
                {
                    _9518 = all(bool2(_12597.x < 1.0f.xx.x, _12597.y < 1.0f.xx.y));
                }
                else
                {
                    _9518 = _9512;
                }
                _5166 = _9518;
            }
            else
            {
                _5166 = _5160;
            }
            bool _5171;
            if (_5166)
            {
                bool _9523 = all(bool2(_12599.x > 0.0f.xx.x, _12599.y > 0.0f.xx.y));
                bool _9529;
                if (_9523)
                {
                    _9529 = all(bool2(_12599.x < 1.0f.xx.x, _12599.y < 1.0f.xx.y));
                }
                else
                {
                    _9529 = _9523;
                }
                _5171 = _9529;
            }
            else
            {
                _5171 = _5166;
            }
            bool _12973;
            float4 _12982;
            if (_5171)
            {
                uint _9536_dummy_parameter;
                float _9560 = log(((r_depth_tm1.Load(int3(int2(floor(_12597 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9536_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _9568_dummy_parameter;
                float _9592 = log(((r_depth_tp1.Load(int3(int2(floor(_12599 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9568_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _5182 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5189;
                if (_5182)
                {
                    _5189 = _9592 > (_9560 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5189 = _5182;
                }
                bool _12978;
                float4 _13000;
                if (_5189)
                {
                    _13000 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _12978 = true;
                }
                else
                {
                    bool _5195 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5202;
                    if (_5195)
                    {
                        _5202 = _9560 > (_9592 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5202 = _5195;
                    }
                    bool4 _15210 = _5202.xxxx;
                    _13000 = float4(_15210.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _12987.x, _15210.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _12987.y, _15210.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _12987.z, _15210.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _12987.w);
                    _12978 = _5202 ? true : false;
                }
                _12982 = _13000;
                _12973 = _12978;
            }
            else
            {
                _12982 = _12987;
                _12973 = false;
            }
            float4 _13055;
            if (_12973)
            {
                _13055 = 1.0f.xxxx;
            }
            else
            {
                bool _5213 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5219;
                if (_5213)
                {
                    _5219 = _12982.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5219 = _5213;
                }
                bool _5224;
                if (_5219)
                {
                    bool _9598 = all(bool2(_12599.x > 0.0f.xx.x, _12599.y > 0.0f.xx.y));
                    bool _9604;
                    if (_9598)
                    {
                        _9604 = all(bool2(_12599.x < 1.0f.xx.x, _12599.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9604 = _9598;
                    }
                    _5224 = _9604;
                }
                else
                {
                    _5224 = _5219;
                }
                float4 _13056;
                if (_5224)
                {
                    float _13009;
                    if (_12961 >= 0.0f)
                    {
                        _13009 = _12961 - _5157;
                    }
                    else
                    {
                        float _13005;
                        _13005 = 2.0f;
                        float _9661;
                        for (int _13004 = 0; _13004 < 24; _13005 = _9661, _13004++)
                        {
                            float _9625 = float(_13004 & 7) * 0.785398185253143310546875f;
                            int _9627 = _13004 >> 3;
                            int _13006;
                            if (_9627 == 0)
                            {
                                _13006 = 16;
                            }
                            else
                            {
                                _13006 = (_9627 == 1) ? 48 : 96;
                            }
                            uint _9693_dummy_parameter;
                            _9661 = min(_13005, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_12599 + ((cbFI_MvDepthLaneSizeRcp * float(_13006)) * float2(cos(_9625), sin(_9625))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9693_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _13009 = _13005;
                    }
                    uint _9725_dummy_parameter;
                    float4 _13057;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_12599 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9725_dummy_parameter))))), 0)).x) > ((exp((_13009 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _13057 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _13057 = 1.0f.xxxx;
                    }
                    _13056 = _13057;
                }
                else
                {
                    _13056 = 1.0f.xxxx;
                }
                _13055 = _13056;
            }
            bool _5252 = _12961 >= 0.0f;
            bool _5253 = (!_12973) && _5252;
            bool _5260;
            if (_5253)
            {
                _5260 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5260 = _5253;
            }
            bool _5266;
            if (_5260)
            {
                _5266 = _12982.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5266 = _5260;
            }
            bool _5271;
            if (_5266)
            {
                bool _9750 = all(bool2(_12597.x > 0.0f.xx.x, _12597.y > 0.0f.xx.y));
                bool _9756;
                if (_9750)
                {
                    _9756 = all(bool2(_12597.x < 1.0f.xx.x, _12597.y < 1.0f.xx.y));
                }
                else
                {
                    _9756 = _9750;
                }
                _5271 = _9756;
            }
            else
            {
                _5271 = _5266;
            }
            float4 _13080;
            if (_5271)
            {
                float _13049;
                if (_5252)
                {
                    _13049 = _12961 - _5157;
                }
                else
                {
                    float _13045;
                    _13045 = 2.0f;
                    float _9813;
                    for (int _13044 = 0; _13044 < 24; _13045 = _9813, _13044++)
                    {
                        float _9777 = float(_13044 & 7) * 0.785398185253143310546875f;
                        int _9779 = _13044 >> 3;
                        int _13046;
                        if (_9779 == 0)
                        {
                            _13046 = 16;
                        }
                        else
                        {
                            _13046 = (_9779 == 1) ? 48 : 96;
                        }
                        uint _9829_dummy_parameter;
                        _9813 = min(_13045, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_12597 + ((cbFI_MvDepthLaneSizeRcp * float(_13046)) * float2(cos(_9777), sin(_9777))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9829_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _13049 = _13045;
                }
                uint _9877_dummy_parameter;
                float4 _13081;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_12597 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9877_dummy_parameter))))), 0)).x) > ((exp((_13049 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _12429 = _13055;
                    _12429.x = 0.0f;
                    _13081 = _12429;
                }
                else
                {
                    _13081 = _13055;
                }
                _13080 = _13081;
            }
            else
            {
                _13080 = _13055;
            }
            float4 _13093;
            if (_5253)
            {
                float _9904 = (exp(((_12961 - _5157) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5309 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5315;
                if (_5309)
                {
                    _5315 = _12982.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5315 = _5309;
                }
                bool _5320;
                if (_5315)
                {
                    bool _9909 = all(bool2(_12601.x > 0.0f.xx.x, _12601.y > 0.0f.xx.y));
                    bool _9915;
                    if (_9909)
                    {
                        _9915 = all(bool2(_12601.x < 1.0f.xx.x, _12601.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9915 = _9909;
                    }
                    _5320 = _9915;
                }
                else
                {
                    _5320 = _5315;
                }
                bool _5328;
                if (_5320)
                {
                    uint _9922_dummy_parameter;
                    _5328 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_12601 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9922_dummy_parameter))))), 0)).x) > _9904;
                }
                else
                {
                    _5328 = _5320;
                }
                float4 _13091;
                if (_5328)
                {
                    float4 _12432 = _13080;
                    _12432.w = 0.0f;
                    _13091 = _12432;
                }
                else
                {
                    _13091 = _13080;
                }
                bool _5335 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5341;
                if (_5335)
                {
                    _5341 = _12982.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5341 = _5335;
                }
                bool _5346;
                if (_5341)
                {
                    bool _9940 = all(bool2(_12600.x > 0.0f.xx.x, _12600.y > 0.0f.xx.y));
                    bool _9946;
                    if (_9940)
                    {
                        _9946 = all(bool2(_12600.x < 1.0f.xx.x, _12600.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9946 = _9940;
                    }
                    _5346 = _9946;
                }
                else
                {
                    _5346 = _5341;
                }
                bool _5354;
                if (_5346)
                {
                    uint _9953_dummy_parameter;
                    _5354 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_12600 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9953_dummy_parameter))))), 0)).x) > _9904;
                }
                else
                {
                    _5354 = _5346;
                }
                float4 _13094;
                if (_5354)
                {
                    float4 _12435 = _13091;
                    _12435.z = 0.0f;
                    _13094 = _12435;
                }
                else
                {
                    _13094 = _13091;
                }
                _13093 = _13094;
            }
            else
            {
                _13093 = _13080;
            }
            float4 _13165;
            if (any(bool4(_13093.x < 1.0f.xxxx.x, _13093.y < 1.0f.xxxx.y, _13093.z < 1.0f.xxxx.z, _13093.w < 1.0f.xxxx.w)))
            {
                float4 _5365 = _12982 * _13093;
                float _5367 = dot(_5365, 1.0f.xxxx);
                float4 _13166;
                if (_5367 > 0.0f)
                {
                    _13166 = _5365 / _5367.xxxx;
                }
                else
                {
                    bool _5378 = _13093.y == 0.0f;
                    bool _5384;
                    if (_5378)
                    {
                        _5384 = _13093.x > 0.0f;
                    }
                    else
                    {
                        _5384 = _5378;
                    }
                    bool _5389;
                    if (_5384)
                    {
                        bool _9971 = all(bool2(_12597.x > 0.0f.xx.x, _12597.y > 0.0f.xx.y));
                        bool _9977;
                        if (_9971)
                        {
                            _9977 = all(bool2(_12597.x < 1.0f.xx.x, _12597.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _9977 = _9971;
                        }
                        _5389 = _9977;
                    }
                    else
                    {
                        _5389 = _5384;
                    }
                    float4 _13167;
                    if (_5389)
                    {
                        _13167 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5394 = _13093.x == 0.0f;
                        bool _5400;
                        if (_5394)
                        {
                            _5400 = _13093.y > 0.0f;
                        }
                        else
                        {
                            _5400 = _5394;
                        }
                        bool _5405;
                        if (_5400)
                        {
                            bool _9982 = all(bool2(_12599.x > 0.0f.xx.x, _12599.y > 0.0f.xx.y));
                            bool _9988;
                            if (_9982)
                            {
                                _9988 = all(bool2(_12599.x < 1.0f.xx.x, _12599.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _9988 = _9982;
                            }
                            _5405 = _9988;
                        }
                        else
                        {
                            _5405 = _5400;
                        }
                        bool4 _15213 = _5405.xxxx;
                        _13167 = float4(_15213.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _12982.x, _15213.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _12982.y, _15213.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _12982.z, _15213.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _12982.w);
                    }
                    _13166 = _13167;
                }
                _13165 = _13166;
            }
            else
            {
                _13165 = _12982;
            }
            _13164 = _13165;
        }
        else
        {
            _13164 = _12987;
        }
        float4 _13778;
        bool _14040;
        float3 _14157;
        if (((cbFI_pad0 & 32768u) != 0u) && _5114)
        {
            bool _5422 = _13164.x > 0.00999999977648258209228515625f;
            bool _5425 = _13164.y > 0.00999999977648258209228515625f;
            bool _5434 = (_13164.z + _13164.w) > 0.0199999995529651641845703125f;
            bool _5440;
            if (_5434)
            {
                bool _9993 = all(bool2(_12600.x > 0.0f.xx.x, _12600.y > 0.0f.xx.y));
                bool _9999;
                if (_9993)
                {
                    _9999 = all(bool2(_12600.x < 1.0f.xx.x, _12600.y < 1.0f.xx.y));
                }
                else
                {
                    _9999 = _9993;
                }
                _5440 = _9999;
            }
            else
            {
                _5440 = _5434;
            }
            bool _5445;
            if (_5440)
            {
                bool _10004 = all(bool2(_12601.x > 0.0f.xx.x, _12601.y > 0.0f.xx.y));
                bool _10010;
                if (_10004)
                {
                    _10010 = all(bool2(_12601.x < 1.0f.xx.x, _12601.y < 1.0f.xx.y));
                }
                else
                {
                    _10010 = _10004;
                }
                _5445 = _10010;
            }
            else
            {
                _5445 = _5440;
            }
            bool _5452;
            if (_5445)
            {
                float _13175;
                do
                {
                    bool _10093 = all(bool2(_12600.x > 0.0f.xx.x, _12600.y > 0.0f.xx.y));
                    bool _10099;
                    if (_10093)
                    {
                        _10099 = all(bool2(_12600.x < 1.0f.xx.x, _12600.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10099 = _10093;
                    }
                    bool _10030 = !_10099;
                    bool _10037;
                    if (!_10030)
                    {
                        bool _10104 = all(bool2(_12601.x > 0.0f.xx.x, _12601.y > 0.0f.xx.y));
                        bool _10110;
                        if (_10104)
                        {
                            _10110 = all(bool2(_12601.x < 1.0f.xx.x, _12601.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _10110 = _10104;
                        }
                        _10037 = !_10110;
                    }
                    else
                    {
                        _10037 = _10030;
                    }
                    if (_10037)
                    {
                        _13175 = 0.0f;
                        break;
                    }
                    uint _10117_dummy_parameter;
                    uint _10133_dummy_parameter;
                    float4 _10058 = mul(float4((float2(_12600.x, 1.0f - _12600.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12600 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10117_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _10060 = _10058.w;
                    if (abs(_10060) < 9.9999999747524270787835121154785e-07f)
                    {
                        _13175 = 0.0f;
                        break;
                    }
                    float _10071 = abs(cbFI_DeviceToViewDepth.y / ((_10058.z / _10060) - cbFI_DeviceToViewDepth.x));
                    float _10074 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12601 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10133_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _13175 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_10071 - _10074) / max(max(_10071, _10074), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5452 = _13175 < 0.5f;
            }
            else
            {
                _5452 = _5445;
            }
            float4 _13190;
            if (_5452)
            {
                uint _10183_dummy_parameter;
                uint _10214_dummy_parameter;
                float4 _13191;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_12600 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10183_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12601 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10214_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _13191 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _13191 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _13190 = _13191;
            }
            else
            {
                _13190 = 1.0f.xxxx;
            }
            bool _5476;
            if (_8954)
            {
                bool _10243 = all(bool2(_12597.x > 0.0f.xx.x, _12597.y > 0.0f.xx.y));
                bool _10249;
                if (_10243)
                {
                    _10249 = all(bool2(_12597.x < 1.0f.xx.x, _12597.y < 1.0f.xx.y));
                }
                else
                {
                    _10249 = _10243;
                }
                _5476 = _10249;
            }
            else
            {
                _5476 = _8954;
            }
            bool _5482;
            if (_8954)
            {
                bool _10254 = all(bool2(_12599.x > 0.0f.xx.x, _12599.y > 0.0f.xx.y));
                bool _10260;
                if (_10254)
                {
                    _10260 = all(bool2(_12599.x < 1.0f.xx.x, _12599.y < 1.0f.xx.y));
                }
                else
                {
                    _10260 = _10254;
                }
                _5482 = _10260;
            }
            else
            {
                _5482 = _8954;
            }
            bool _5488;
            if (_8986)
            {
                bool _10265 = all(bool2(_12600.x > 0.0f.xx.x, _12600.y > 0.0f.xx.y));
                bool _10271;
                if (_10265)
                {
                    _10271 = all(bool2(_12600.x < 1.0f.xx.x, _12600.y < 1.0f.xx.y));
                }
                else
                {
                    _10271 = _10265;
                }
                _5488 = _10271;
            }
            else
            {
                _5488 = _8986;
            }
            bool _5494;
            if (_8986)
            {
                bool _10276 = all(bool2(_12601.x > 0.0f.xx.x, _12601.y > 0.0f.xx.y));
                bool _10282;
                if (_10276)
                {
                    _10282 = all(bool2(_12601.x < 1.0f.xx.x, _12601.y < 1.0f.xx.y));
                }
                else
                {
                    _10282 = _10276;
                }
                _5494 = _10282;
            }
            else
            {
                _5494 = _8986;
            }
            bool _5497 = _5488 != _5494;
            bool _5503;
            if (_5497)
            {
                _5503 = _5476 || _5482;
            }
            else
            {
                _5503 = _5497;
            }
            float4 _13289;
            if (_5503)
            {
                float4 _12462 = _13190;
                _12462.z = 0.0f;
                _12462.w = 0.0f;
                _13289 = _12462;
            }
            else
            {
                _13289 = _13190;
            }
            bool _5510 = _5476 && _5422;
            bool _5513 = _5482 && _5425;
            float4 _13394;
            float3 _14258;
            if (_5510 || _5513)
            {
                float _13284;
                do
                {
                    uint4 _10421 = r_warped_motion_qdata_tp1.Load(int3(_12714, 0));
                    uint _10422 = _10421.x;
                    if (_10422 != 0u)
                    {
                        float _13283;
                        if (_10422 == 0u)
                        {
                            _13283 = -1.0f;
                        }
                        else
                        {
                            _13283 = float((_10422 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13284 = _13283;
                        break;
                    }
                    int _13266;
                    uint _13267;
                    _13267 = _10422;
                    _13266 = -1;
                    uint _13282;
                    for (; _13266 <= 1; _13267 = _13282, _13266++)
                    {
                        _13282 = _13267;
                        for (int _13280 = -1; _13280 <= 1; )
                        {
                            _13282 = max(_13282, r_warped_motion_qdata_tp1.Load(int3(clamp(_12714 + int2(_13280, _13266), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _13280++;
                            continue;
                        }
                    }
                    if (_13267 != 0u)
                    {
                        float _13279;
                        if (_13267 == 0u)
                        {
                            _13279 = -1.0f;
                        }
                        else
                        {
                            _13279 = float((_13267 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13284 = _13279;
                        break;
                    }
                    uint _13269;
                    _13269 = 4294967295u;
                    uint _15180;
                    for (int _13268 = 0; _13268 < 8; _13269 = _15180, _13268++)
                    {
                        int _13272 = 0;
                        for (;;)
                        {
                            if (_13272 < 5)
                            {
                                int2 _10372 = _12714 + (_1098[_13268] * _1107[_13272].xx);
                                bool _10375 = any(bool2(_10372.x < int2(0, 0).x, _10372.y < int2(0, 0).y));
                                bool _10383;
                                if (!_10375)
                                {
                                    _10383 = any(bool2(_10372.x >= cbFI_MvDepthLaneSize.x, _10372.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _10383 = _10375;
                                }
                                if (_10383)
                                {
                                    _15180 = _13269;
                                    break;
                                }
                                uint4 _10461 = r_warped_motion_qdata_tp1.Load(int3(_10372, 0));
                                uint _10462 = _10461.x;
                                if (_10462 != 0u)
                                {
                                    _15180 = min(_13269, _10462);
                                    break;
                                }
                                _13272++;
                                continue;
                            }
                            else
                            {
                                _15180 = _13269;
                                break;
                            }
                        }
                    }
                    float _13271;
                    if (_13269 == 4294967295u)
                    {
                        _13271 = -1.0f;
                    }
                    else
                    {
                        float _13270;
                        if (_13269 == 0u)
                        {
                            _13270 = -1.0f;
                        }
                        else
                        {
                            _13270 = float((_13269 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13271 = _13270;
                    }
                    _13284 = _13271;
                    break;
                } while(false);
                bool _5521 = _13284 < 0.0f;
                float _13285;
                if (_5521)
                {
                    _13285 = 0.0f;
                }
                else
                {
                    _13285 = _13284 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _10483_dummy_parameter;
                uint _10515_dummy_parameter;
                float4 _13322;
                if ((_5521 && _5510) && _5513)
                {
                    uint _10547_dummy_parameter;
                    float _10571 = log(((r_depth_tm1.Load(int3(int2(floor(_12597 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10547_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _10579_dummy_parameter;
                    float _10603 = log(((r_depth_tp1.Load(int3(int2(floor(_12599 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10579_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _13323;
                    if (_10571 > (_10603 + 0.07999999821186065673828125f))
                    {
                        float4 _12466 = _13289;
                        _12466.x = 0.0f;
                        _13323 = _12466;
                    }
                    else
                    {
                        float4 _13324;
                        if (_10603 > (_10571 + 0.07999999821186065673828125f))
                        {
                            float4 _12468 = _13289;
                            _12468.y = 0.0f;
                            _13324 = _12468;
                        }
                        else
                        {
                            _13324 = _13289;
                        }
                        _13323 = _13324;
                    }
                    _13322 = _13323;
                }
                else
                {
                    _13322 = _13289;
                }
                float _5573 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5575 = _13284 >= 0.0f;
                float _13305;
                if (_5575)
                {
                    _13305 = _13284 - _5573;
                }
                else
                {
                    float _13301;
                    if (_5510)
                    {
                        float _13300;
                        _13300 = 2.0f;
                        float _10661;
                        for (int _13299 = 0; _13299 < 24; _13300 = _10661, _13299++)
                        {
                            float _10625 = float(_13299 & 7) * 0.785398185253143310546875f;
                            int _10627 = _13299 >> 3;
                            int _13302;
                            if (_10627 == 0)
                            {
                                _13302 = 16;
                            }
                            else
                            {
                                _13302 = (_10627 == 1) ? 48 : 96;
                            }
                            uint _10677_dummy_parameter;
                            _10661 = min(_13300, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_12597 + ((cbFI_MvDepthLaneSizeRcp * float(_13302)) * float2(cos(_10625), sin(_10625))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10677_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _13301 = _13300;
                    }
                    else
                    {
                        _13301 = 0.0f;
                    }
                    _13305 = _13301;
                }
                float _13312;
                if (_5575)
                {
                    _13312 = _13284 - _5573;
                }
                else
                {
                    float _13308;
                    if (_5513)
                    {
                        float _13307;
                        _13307 = 2.0f;
                        float _10775;
                        for (int _13306 = 0; _13306 < 24; _13307 = _10775, _13306++)
                        {
                            float _10739 = float(_13306 & 7) * 0.785398185253143310546875f;
                            int _10741 = _13306 >> 3;
                            int _13309;
                            if (_10741 == 0)
                            {
                                _13309 = 16;
                            }
                            else
                            {
                                _13309 = (_10741 == 1) ? 48 : 96;
                            }
                            uint _10807_dummy_parameter;
                            _10775 = min(_13307, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_12599 + ((cbFI_MvDepthLaneSizeRcp * float(_13309)) * float2(cos(_10739), sin(_10739))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10807_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _13308 = _13307;
                    }
                    else
                    {
                        _13308 = 0.0f;
                    }
                    _13312 = _13308;
                }
                float _13313;
                if (_5510)
                {
                    uint _10839_dummy_parameter;
                    _13313 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_12597 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10839_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _13313 = 0.0f;
                }
                float _13314;
                if (_5513)
                {
                    uint _10859_dummy_parameter;
                    _13314 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_12599 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10859_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _13314 = 0.0f;
                }
                bool _5630;
                if (_5510)
                {
                    _5630 = _13313 > ((exp((_13305 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5630 = _5510;
                }
                float4 _13330;
                if (_5630)
                {
                    float4 _12470 = _13322;
                    _12470.x = 0.0f;
                    _13330 = _12470;
                }
                else
                {
                    _13330 = _13322;
                }
                bool _5642;
                if (_5513)
                {
                    _5642 = _13314 > ((exp((_13312 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5642 = _5513;
                }
                float4 _13332;
                if (_5642)
                {
                    float4 _12472 = _13330;
                    _12472.y = 0.0f;
                    _13332 = _12472;
                }
                else
                {
                    _13332 = _13330;
                }
                float4 _13395;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5575)
                {
                    bool _5662;
                    if (_5510)
                    {
                        _5662 = _13313 < ((exp((_13305 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5662 = _5510;
                    }
                    float4 _13334;
                    if (_5662)
                    {
                        float4 _12474 = _13332;
                        _12474.x = 0.0f;
                        _13334 = _12474;
                    }
                    else
                    {
                        _13334 = _13332;
                    }
                    bool _5674;
                    if (_5513)
                    {
                        _5674 = _13314 < ((exp((_13312 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5674 = _5513;
                    }
                    float4 _13396;
                    if (_5674)
                    {
                        float4 _12476 = _13334;
                        _12476.y = 0.0f;
                        _13396 = _12476;
                    }
                    else
                    {
                        _13396 = _13334;
                    }
                    _13395 = _13396;
                }
                else
                {
                    _13395 = _13332;
                }
                _14258 = float3(_13285, log(((r_depth_tm1.Load(int3(int2(floor(_12597 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10483_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_12599 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10515_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _13394 = _13395;
            }
            else
            {
                _14258 = float3(0.0f, 0.0f, 0.5f);
                _13394 = _13289;
            }
            bool _5685 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5434;
            bool _5691;
            if (_5685)
            {
                _5691 = _5488 || _5494;
            }
            else
            {
                _5691 = _5685;
            }
            float4 _13417;
            if (_5691)
            {
                float _13389;
                do
                {
                    uint4 _11039 = r_warped_motion_qdata_tp1.Load(int3(_12714, 0));
                    uint _11040 = _11039.x;
                    if (_11040 != 0u)
                    {
                        float _13388;
                        if (_11040 == 0u)
                        {
                            _13388 = -1.0f;
                        }
                        else
                        {
                            _13388 = float((_11040 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13389 = _13388;
                        break;
                    }
                    int _13371;
                    uint _13372;
                    _13372 = _11040;
                    _13371 = -1;
                    uint _13387;
                    for (; _13371 <= 1; _13372 = _13387, _13371++)
                    {
                        _13387 = _13372;
                        for (int _13385 = -1; _13385 <= 1; )
                        {
                            _13387 = max(_13387, r_warped_motion_qdata_tp1.Load(int3(clamp(_12714 + int2(_13385, _13371), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _13385++;
                            continue;
                        }
                    }
                    if (_13372 != 0u)
                    {
                        float _13384;
                        if (_13372 == 0u)
                        {
                            _13384 = -1.0f;
                        }
                        else
                        {
                            _13384 = float((_13372 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13389 = _13384;
                        break;
                    }
                    uint _13374;
                    _13374 = 4294967295u;
                    uint _15181;
                    for (int _13373 = 0; _13373 < 8; _13374 = _15181, _13373++)
                    {
                        int _13377 = 0;
                        for (;;)
                        {
                            if (_13377 < 5)
                            {
                                int2 _10990 = _12714 + (_1098[_13373] * _1107[_13377].xx);
                                bool _10993 = any(bool2(_10990.x < int2(0, 0).x, _10990.y < int2(0, 0).y));
                                bool _11001;
                                if (!_10993)
                                {
                                    _11001 = any(bool2(_10990.x >= cbFI_MvDepthLaneSize.x, _10990.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _11001 = _10993;
                                }
                                if (_11001)
                                {
                                    _15181 = _13374;
                                    break;
                                }
                                uint4 _11079 = r_warped_motion_qdata_tp1.Load(int3(_10990, 0));
                                uint _11080 = _11079.x;
                                if (_11080 != 0u)
                                {
                                    _15181 = min(_13374, _11080);
                                    break;
                                }
                                _13377++;
                                continue;
                            }
                            else
                            {
                                _15181 = _13374;
                                break;
                            }
                        }
                    }
                    float _13376;
                    if (_13374 == 4294967295u)
                    {
                        _13376 = -1.0f;
                    }
                    else
                    {
                        float _13375;
                        if (_13374 == 0u)
                        {
                            _13375 = -1.0f;
                        }
                        else
                        {
                            _13375 = float((_13374 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13376 = _13375;
                    }
                    _13389 = _13376;
                    break;
                } while(false);
                float4 _13418;
                if (_13389 >= 0.0f)
                {
                    float _11101 = (exp((_13389 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5710;
                    if (_5488)
                    {
                        uint _11108_dummy_parameter;
                        _5710 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_12600 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11108_dummy_parameter))))), 0)).x) > _11101;
                    }
                    else
                    {
                        _5710 = _5488;
                    }
                    float4 _13407;
                    if (_5710)
                    {
                        float4 _12478 = _13394;
                        _12478.z = 0.0f;
                        _13407 = _12478;
                    }
                    else
                    {
                        _13407 = _13394;
                    }
                    bool _5722;
                    if (_5494)
                    {
                        uint _11128_dummy_parameter;
                        _5722 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_12601 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11128_dummy_parameter))))), 0)).x) > _11101;
                    }
                    else
                    {
                        _5722 = _5494;
                    }
                    float4 _13419;
                    if (_5722)
                    {
                        float4 _12480 = _13407;
                        _12480.w = 0.0f;
                        _13419 = _12480;
                    }
                    else
                    {
                        _13419 = _13407;
                    }
                    _13418 = _13419;
                }
                else
                {
                    _13418 = _13394;
                }
                _13417 = _13418;
            }
            else
            {
                _13417 = _13394;
            }
            bool _5730 = _5476 != _5482;
            bool _5737;
            if (_5730)
            {
                _5737 = _5476 ? _5422 : _5425;
            }
            else
            {
                _5737 = _5730;
            }
            bool _5744;
            if (_5737)
            {
                _5744 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5744 = _5737;
            }
            float4 _13502;
            if (_5744)
            {
                bool2 _5749 = _5476.xx;
                float2 _5750 = float2(_5749.x ? _12597.x : _12599.x, _5749.y ? _12597.y : _12599.y);
                float _13409;
                if (_5476)
                {
                    uint _11148_dummy_parameter;
                    _13409 = r_depth_tm1.Load(int3(int2(floor(_5750 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11148_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _11164_dummy_parameter;
                    _13409 = r_depth_tp1.Load(int3(int2(floor(_5750 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11164_dummy_parameter))))), 0)).x;
                }
                float4x4 _13410;
                if (_5476)
                {
                    _13410 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _13410 = cbFI_MotionTP1ToTM1;
                }
                float2 _13411;
                do
                {
                    float _11191 = _5750.x;
                    float _11194 = 1.0f - _5750.y;
                    float4 _11205 = mul(float4((float2(_11191, _11194) * 2.0f) - 1.0f.xx, _13409, 1.0f), _13410);
                    float _11207 = _11205.w;
                    if (!(_11207 > 9.9999999747524270787835121154785e-07f))
                    {
                        _13411 = 1000000.0f.xx;
                        break;
                    }
                    float2 _11220 = ((_11205.xy / _11207.xx) + 1.0f.xx) * 0.5f;
                    _13411 = float2(_11220.x - _11191, _11194 - _11220.y);
                    break;
                } while(false);
                float2 _5780 = float2(cbFI_DisplaySize);
                float4 _13503;
                if (!(length(((_5750 + _13411) - float2(_5749.x ? _12599.x : _12597.x, _5749.y ? _12599.y : _12597.y)) * _5780) <= ((0.100000001490116119384765625f * length(_13411 * _5780)) + 8.0f)))
                {
                    float4 _13504;
                    if (_5476)
                    {
                        float4 _12490 = _13417;
                        _12490.x = 0.0f;
                        _13504 = _12490;
                    }
                    else
                    {
                        float4 _12492 = _13417;
                        _12492.y = 0.0f;
                        _13504 = _12492;
                    }
                    _13503 = _13504;
                }
                else
                {
                    _13503 = _13417;
                }
                _13502 = _13503;
            }
            else
            {
                _13502 = _13417;
            }
            float4 _5805 = _13164 * _13502;
            float _5807 = dot(_5805, 1.0f.xxxx);
            float4 _13779;
            bool _14041;
            if (_5807 > 0.0f)
            {
                _14041 = _12871;
                _13779 = _5805 / _5807.xxxx;
            }
            else
            {
                bool _5818 = any(bool4(_13502.x < 1.0f.xxxx.x, _13502.y < 1.0f.xxxx.y, _13502.z < 1.0f.xxxx.z, _13502.w < 1.0f.xxxx.w));
                if (_5818)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11242;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11242);
                    }
                }
                bool4 _15216 = _5818.xxxx;
                _14041 = _5818 ? true : _12871;
                _13779 = float4(_15216.x ? 0.0f.xxxx.x : _13164.x, _15216.y ? 0.0f.xxxx.y : _13164.y, _15216.z ? 0.0f.xxxx.z : _13164.z, _15216.w ? 0.0f.xxxx.w : _13164.w);
            }
            _14157 = _14258;
            _14040 = _14041;
            _13778 = _13779;
        }
        else
        {
            _14157 = float3(0.0f, 0.0f, 0.5f);
            _14040 = _12871;
            _13778 = _13164;
        }
        uint _5827 = (cbFI_pad0 >> 24u) & 31u;
        uint _5831 = (cbFI_pad0 >> 16u) & 255u;
        bool _5833 = _5827 != 0u;
        bool _5835 = _5831 == 12u;
        bool _5838 = _5831 == 13u;
        float4 _13795;
        if ((_5833 || _5835) || _5838)
        {
            float _13505;
            do
            {
                bool _11326 = all(bool2(_12600.x > 0.0f.xx.x, _12600.y > 0.0f.xx.y));
                bool _11332;
                if (_11326)
                {
                    _11332 = all(bool2(_12600.x < 1.0f.xx.x, _12600.y < 1.0f.xx.y));
                }
                else
                {
                    _11332 = _11326;
                }
                bool _11263 = !_11332;
                bool _11270;
                if (!_11263)
                {
                    bool _11337 = all(bool2(_12601.x > 0.0f.xx.x, _12601.y > 0.0f.xx.y));
                    bool _11343;
                    if (_11337)
                    {
                        _11343 = all(bool2(_12601.x < 1.0f.xx.x, _12601.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11343 = _11337;
                    }
                    _11270 = !_11343;
                }
                else
                {
                    _11270 = _11263;
                }
                if (_11270)
                {
                    _13505 = 0.0f;
                    break;
                }
                uint _11350_dummy_parameter;
                uint _11366_dummy_parameter;
                float4 _11291 = mul(float4((float2(_12600.x, 1.0f - _12600.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12600 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11350_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _11293 = _11291.w;
                if (abs(_11293) < 9.9999999747524270787835121154785e-07f)
                {
                    _13505 = 0.0f;
                    break;
                }
                float _11304 = abs(cbFI_DeviceToViewDepth.y / ((_11291.z / _11293) - cbFI_DeviceToViewDepth.x));
                float _11307 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12601 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11366_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _13505 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11304 - _11307) / max(max(_11304, _11307), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _11414 = all(bool2(_12601.x > 0.0f.xx.x, _12601.y > 0.0f.xx.y));
            bool _11420;
            if (_11414)
            {
                _11420 = all(bool2(_12601.x < 1.0f.xx.x, _12601.y < 1.0f.xx.y));
            }
            else
            {
                _11420 = _11414;
            }
            float _13506;
            if (_11420)
            {
                uint _11427_dummy_parameter;
                _13506 = length((_6668 + (r_motion_tp1.Load(int3(int2(floor(_12601 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _11427_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _13506 = 1000000.0f;
            }
            float _13517;
            if ((_5827 & 1u) != 0u)
            {
                _13517 = _13505;
            }
            else
            {
                _13517 = 1.0f;
            }
            float _13518;
            if ((_5827 & 2u) != 0u)
            {
                _13518 = _13517 * (1.0f - smoothstep(2.0f, 8.0f, _13506));
            }
            else
            {
                _13518 = _13517;
            }
            float _13519;
            if ((_5827 & 4u) != 0u)
            {
                _13519 = _13518 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7389 - _7397) - length(_7373 - _7381))));
            }
            else
            {
                _13519 = _13518;
            }
            float _13789;
            if ((_5827 & 8u) != 0u)
            {
                _13789 = lerp(1.0f, _13519, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7373 - _7381)));
            }
            else
            {
                _13789 = _13519;
            }
            bool _5913 = (_5827 & 16u) != 0u;
            bool _5922;
            if (_5913)
            {
                _5922 = length(_12595 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5922 = _5913;
            }
            float _15218 = _5922 ? 1.0f : _13789;
            bool _5928 = _5833 && _8954;
            bool _5933;
            if (_5928)
            {
                bool _11452 = all(bool2(_12597.x > 0.0f.xx.x, _12597.y > 0.0f.xx.y));
                bool _11458;
                if (_11452)
                {
                    _11458 = all(bool2(_12597.x < 1.0f.xx.x, _12597.y < 1.0f.xx.y));
                }
                else
                {
                    _11458 = _11452;
                }
                _5933 = _11458;
            }
            else
            {
                _5933 = _5928;
            }
            bool _5938;
            if (_5933)
            {
                bool _11463 = all(bool2(_12599.x > 0.0f.xx.x, _12599.y > 0.0f.xx.y));
                bool _11469;
                if (_11463)
                {
                    _11469 = all(bool2(_12599.x < 1.0f.xx.x, _12599.y < 1.0f.xx.y));
                }
                else
                {
                    _11469 = _11463;
                }
                _5938 = _11469;
            }
            else
            {
                _5938 = _5933;
            }
            float4 _13796;
            if (_5938)
            {
                float _5944 = _13778.x + _13778.y;
                float _5953 = (_13778.z + _13778.w) * (1.0f - _15218);
                float _13792;
                if (_5944 > 9.9999997473787516355514526367188e-06f)
                {
                    _13792 = _13778.x / _5944;
                }
                else
                {
                    _13792 = _4683;
                }
                _13796 = float4(_13778.x + (_5953 * _13792), _13778.y + (_5953 * (1.0f - _13792)), _13778.zw * _15218);
            }
            else
            {
                _13796 = _13778;
            }
            _13795 = _13796;
        }
        else
        {
            _13795 = _13778;
        }
        float3 _6014 = (((_7373 * _13795.x) + (_7381 * _13795.y)) + (_7389 * _13795.z)) + (_7397 * _13795.w);
        float3 _14983;
        if (_4699 && (_13810 > 0.0f))
        {
            uint _11476_dummy_parameter;
            float2 _11491 = r_motion_tp1.Load(int3(int2(floor(_4458 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _11476_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _14032;
            if (_6696)
            {
                float2 _11536 = clamp((((_12574 + (_11491 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _11539 = tan(_11536.x);
                _14032 = (float2(_11539 / cbFI_DeviceToViewDepth.z, (tan(_11536.y) * sqrt(1.0f + (_11539 * _11539))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _14032 = _12574 + (_11491 * cbFI_Timestep);
            }
            float2 _14033;
            if (_6696)
            {
                float2 _11615 = clamp((((_12574 + (_11491 * _4673)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _11618 = tan(_11615.x);
                _14033 = (float2(_11618 / cbFI_DeviceToViewDepth.z, (tan(_11615.y) * sqrt(1.0f + (_11618 * _11618))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _14033 = _12574 + (_11491 * _4673);
            }
            _14983 = lerp(_6014, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14032, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _14033, 0.0f).xyz, cbFI_Timestep.xxx), _13810.xxx);
        }
        else
        {
            _14983 = _6014;
        }
        float3 _14982;
        if (_14040)
        {
            float3 _11660 = r_current_interpolation_source.Load(int3(_3999, 0)).xyz;
            float3 _14984;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _8954)
            {
                uint _11667_dummy_parameter;
                float _14147;
                _14147 = r_depth_tm1.Load(int3(int2(floor(_12597 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11667_dummy_parameter))))), 0)).x;
                float _6095;
                for (int _14146 = 0; _14146 < 24; _14147 = _6095, _14146++)
                {
                    float _6067 = float(_14146 & 7) * 0.785398185253143310546875f;
                    int _6069 = _14146 >> 3;
                    int _15034;
                    if (_6069 == 0)
                    {
                        _15034 = 16;
                    }
                    else
                    {
                        _15034 = (_6069 == 1) ? 48 : 96;
                    }
                    uint _11687_dummy_parameter;
                    _6095 = max(_14147, r_depth_tm1.Load(int3(int2(floor(clamp(_12597 + ((cbFI_MvDepthLaneSizeRcp * float(_15034)) * float2(cos(_6067), sin(_6067))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11687_dummy_parameter))))), 0)).x);
                }
                float2 _14148;
                do
                {
                    float _11709 = 1.0f - _12597.y;
                    float4 _11720 = mul(float4((float2(_12597.x, _11709) * 2.0f) - 1.0f.xx, _14147, 1.0f), cbFI_MotionTM1ToTM2);
                    float _11722 = _11720.w;
                    if (!(_11722 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14148 = 1000000.0f.xx;
                        break;
                    }
                    float2 _11735 = ((_11720.xy / _11722.xx) + 1.0f.xx) * 0.5f;
                    _14148 = float2(_11735.x - _12597.x, _11709 - _11735.y);
                    break;
                } while(false);
                float2 _6106 = _12597 + _14148;
                bool _11753 = all(bool2(_6106.x > 0.0f.xx.x, _6106.y > 0.0f.xx.y));
                bool _11759;
                if (_11753)
                {
                    _11759 = all(bool2(_6106.x < 1.0f.xx.x, _6106.y < 1.0f.xx.y));
                }
                else
                {
                    _11759 = _11753;
                }
                float3 _14985;
                if (_11759)
                {
                    float _6112 = abs(cbFI_DeviceToViewDepth.y / (_14147 - cbFI_DeviceToViewDepth.x));
                    uint _11779_dummy_parameter;
                    int2 _11779 = int2(spvTextureSize(r_depth_m2, uint(0), _11779_dummy_parameter));
                    float _6116 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6106 * float2(_11779))), int2(0, 0), _11779 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _14990;
                    if (abs(_6116 - _6112) <= (0.20000000298023223876953125f * max(_6116, _6112)))
                    {
                        uint _11813_dummy_parameter;
                        int2 _11813 = int2(spvTextureSize(r_colour_m2, uint(0), _11813_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _11836;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _11836);
                        }
                        _14990 = r_colour_m2.Load(int3(clamp(int2(floor(_6106 * float2(_11813))), int2(0, 0), _11813 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _11846;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _11846);
                        }
                        _14990 = _11660;
                    }
                    _14985 = _14990;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11856;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _11856);
                    }
                    _14985 = _11660;
                }
                _14984 = _14985;
            }
            else
            {
                _14984 = _11660;
            }
            _14982 = _14984;
        }
        else
        {
            _14982 = _14983;
        }
        uint _6144 = cbFI_pad0 & 255u;
        bool _14871;
        float3 _14981;
        if (_6144 != 0u)
        {
            float3 _6149 = r_present_backbuffer.Load(int3(_3999, 0)).xyz;
            float3 _6153 = r_current_interpolation_source.Load(int3(_3999, 0)).xyz;
            float3 _6157 = abs(_6149 - _6153);
            float3 _14151;
            if (_6144 == 2u)
            {
                _14151 = (abs(_6153) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _14151 = 0.000244140625f.xxx;
            }
            bool _6173 = any(bool3(_6157.x > _14151.x, _6157.y > _14151.y, _6157.z > _14151.z));
            bool3 _15219 = _6173.xxx;
            _14981 = float3(_15219.x ? _6149.x : _14982.x, _15219.y ? _6149.y : _14982.y, _15219.z ? _6149.z : _14982.z);
            _14871 = _6173;
        }
        else
        {
            _14981 = _14982;
            _14871 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _11871;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _11871);
        }
        float3 _14964;
        if (_5831 == 1u)
        {
            _14964 = lerp(_7373, _7381, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _14965;
            if (_5831 == 2u)
            {
                _14965 = lerp(_7389, _7397, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _14966;
                if (_5831 == 3u)
                {
                    _14966 = float(_14871).xxx;
                }
                else
                {
                    float3 _14967;
                    if (_5831 == 4u)
                    {
                        _14967 = float3(((_12595 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _14968;
                        if (_5831 == 5u)
                        {
                            _14968 = float3(((_6668 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _14969;
                            if (_5831 == 6u)
                            {
                                _14969 = float3(_13795.xy, _13795.z + _13795.w);
                            }
                            else
                            {
                                float3 _14970;
                                if (_5831 == 7u)
                                {
                                    _14970 = r_current_interpolation_source.Load(int3(_3999, 0)).xyz;
                                }
                                else
                                {
                                    float3 _14971;
                                    if (_5831 == 8u)
                                    {
                                        _14971 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4458, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _14972;
                                        if (_5835)
                                        {
                                            uint _11893_dummy_parameter;
                                            uint _11925_dummy_parameter;
                                            _14972 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4458 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11893_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4458 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11925_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _14973;
                                            if (_5838)
                                            {
                                                _14973 = _7389;
                                            }
                                            else
                                            {
                                                float3 _14974;
                                                if (_5831 == 20u)
                                                {
                                                    _14974 = _7373;
                                                }
                                                else
                                                {
                                                    float3 _14975;
                                                    if (_5831 == 21u)
                                                    {
                                                        _14975 = _7381;
                                                    }
                                                    else
                                                    {
                                                        float3 _14976;
                                                        if (_5831 == 22u)
                                                        {
                                                            _14976 = _7397;
                                                        }
                                                        else
                                                        {
                                                            float3 _14977;
                                                            if (_5831 == 18u)
                                                            {
                                                                _14977 = _14575;
                                                            }
                                                            else
                                                            {
                                                                float3 _14978;
                                                                if (_5831 == 19u)
                                                                {
                                                                    _14978 = _14363;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _15221 = (_5831 == 23u).xxx;
                                                                    _14978 = float3(_15221.x ? _14157.x : _14981.x, _15221.y ? _14157.y : _14981.y, _15221.z ? _14157.z : _14981.z);
                                                                }
                                                                _14977 = _14978;
                                                            }
                                                            _14976 = _14977;
                                                        }
                                                        _14975 = _14976;
                                                    }
                                                    _14974 = _14975;
                                                }
                                                _14973 = _14974;
                                            }
                                            _14972 = _14973;
                                        }
                                        _14971 = _14972;
                                    }
                                    _14970 = _14971;
                                }
                                _14969 = _14970;
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
        float3 _14963;
        if ((_5831 >= 9u) && (_5831 <= 11u))
        {
            uint _6337 = 64u + uint((_12714.y * cbFI_MvDepthLaneSize.x) + _12714.x);
            uint _6341 = rw_nfru_diagnostics.Load<uint>(_6337 * 4 + 0) & 15u;
            float3 _14995;
            if (_5831 == 10u)
            {
                float3 _14962;
                if ((rw_nfru_diagnostics.Load<uint>(_6337 * 4 + 0) & 32u) != 0u)
                {
                    _14962 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _14961;
                    if ((rw_nfru_diagnostics.Load<uint>(_6337 * 4 + 0) & 16u) != 0u)
                    {
                        _14961 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6362 = ((rw_nfru_diagnostics.Load<uint>(_6337 * 4 + 0) & 64u) != 0u).xxx;
                        _14961 = float3(_6362.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6362.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6362.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _14962 = _14961;
                }
                _14995 = _14962;
            }
            else
            {
                float3 _14996;
                if (_5831 == 11u)
                {
                    uint _6375 = (rw_nfru_diagnostics.Load<uint>(_6337 * 4 + 0) >> 8u) & 15u;
                    uint _6378 = (rw_nfru_diagnostics.Load<uint>(_6337 * 4 + 0) >> 12u) & 15u;
                    float3 _14954;
                    if ((_6341 == 2u) || (_6341 == 3u))
                    {
                        _14954 = _3695[_6341];
                    }
                    else
                    {
                        bool _6390 = _6375 == 3u;
                        bool _6392 = _6378 == 3u;
                        float3 _14955;
                        if (_6390 && _6392)
                        {
                            _14955 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _14956;
                            if (_6390)
                            {
                                _14956 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _14957;
                                if (_6392)
                                {
                                    _14957 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _14958;
                                    if ((_6375 == 4u) || (_6378 == 4u))
                                    {
                                        _14958 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _14959;
                                        if ((_6375 == 1u) || (_6378 == 1u))
                                        {
                                            _14959 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _15223 = (_6341 == 1u).xxx;
                                            _14959 = float3(_15223.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _15223.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _15223.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _14958 = _14959;
                                    }
                                    _14957 = _14958;
                                }
                                _14956 = _14957;
                            }
                            _14955 = _14956;
                        }
                        _14954 = _14955;
                    }
                    _14996 = _14954;
                }
                else
                {
                    _14996 = _3695[min(_6341, 7u)];
                }
                _14995 = _14996;
            }
            _14963 = _14995;
        }
        else
        {
            _14963 = _14964;
        }
        float4 _14999;
        if ((_5831 >= 14u) && (_5831 <= 16u))
        {
            float2 _14997;
            if (_5831 == 14u)
            {
                uint _6448_dummy_parameter;
                uint _6454_dummy_parameter;
                _14997 = r_flow_tm1.Load(int3(clamp(int2(floor(_4458 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6448_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6454_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _14998;
                if (_5831 == 16u)
                {
                    uint _11976 = r_warped_flow_qdata_tm1.Load(int3(_4474, 0)).x & 2147483647u;
                    uint _12008 = uint(max((int((_11976 >> 16u) & 15u) - 6), 0));
                    _14998 = ((float2(float((1 - (2 * int((_11976 >> 15u) & 1u))) * int(((_11976 >> uint(7)) & 127u) << _12008)), float((1 - (2 * int((_11976 >> 14u) & 1u))) * int((_11976 & 127u) << _12008))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _14998 = _6668 * float2(cbFI_DisplaySize);
                }
                _14997 = _14998;
            }
            uint2 _6487 = uint2(clamp(round(_14997 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6489 = _6487.x;
            uint _6496 = _6487.y;
            _14999 = float4(float(_6489 & 255u), float((_6489 >> 8u) | ((_6496 & 15u) << 4u)), float(_6496 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _15000;
            if (_5831 == 17u)
            {
                _15000 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4474, 0)).x != 0u), _4918, 0.0f, 1.0f);
            }
            else
            {
                _15000 = float4(_14963, 1.0f);
            }
            _14999 = _15000;
        }
        rw_output[_3999] = _14999.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6540 = ((uint(_3999.y) * uint(cbFI_DisplaySize.x)) + uint(_3999.x)) * 6u;
            uint _12054 = spvPackHalf2x16(clamp(_7372.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6540 * 4 + 0, (((_12054 & 32767u) >> 4u) | ((((_12054 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7372.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12089 = spvPackHalf2x16(clamp(_7380.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6540 + 1u) * 4 + 0, (((_12089 & 32767u) >> 4u) | ((((_12089 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7380.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12124 = spvPackHalf2x16(clamp(_7388.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6540 + 2u) * 4 + 0, (((_12124 & 32767u) >> 4u) | ((((_12124 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7388.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12159 = spvPackHalf2x16(clamp(_7396.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6540 + 3u) * 4 + 0, (((_12159 & 32767u) >> 4u) | ((((_12159 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7396.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _12186 = r_current_interpolation_source.Load(int3(_3999, 0));
            uint _12200 = spvPackHalf2x16(clamp(_12186.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6540 + 4u) * 4 + 0, (((_12200 & 32767u) >> 4u) | ((((_12200 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12186.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _15033;
            if (_14871 || (_5831 != 0u))
            {
                _15033 = 4294967295u;
            }
            else
            {
                uint _12235 = spvPackHalf2x16(clamp(_14999.xy, 0.0f.xx, 65000.0f.xx));
                _15033 = (((_12235 & 32767u) >> 4u) | ((((_12235 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_14999.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6540 + 5u) * 4 + 0, _15033);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3999] = float4(r_current_interpolation_source.Load(int3(_3999, 0)).xyz, 1.0f).xyz;
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
