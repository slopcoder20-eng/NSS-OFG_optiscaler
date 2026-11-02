static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1192[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1201[5] = { 2, 4, 7, 11, 16 };
static const float3 _3782[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4086 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4086.x >= cbFI_DisplaySize.x, _4086.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4086] = float4(r_present_backbuffer.Load(int3(_4086, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4086] = float4(r_current_interpolation_source.Load(int3(_4086, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4560 = (float2(_4086) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4562 = float2(cbFI_MvDepthLaneSize);
        int2 _4571 = int2(floor(_4560 * _4562));
        int2 _4576 = int2(floor(_4560 * float2(cbFI_FlowLaneSize)));
        float4 _6764 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4560 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6770 = r_warped_filled_flow_tm1.Load(int3(_4576, 0)).xy;
        float2 _6776 = r_warped_filled_motion_tp1.Load(int3(_4571, 0)).xy;
        bool _6798 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _14096;
        if (_6798)
        {
            float _6811 = ((2.0f * _4560.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _14096 = float2(atan(_6811) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4560.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6811 * _6811))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _14096 = _4560;
        }
        bool _4597 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _14117;
        bool _14259;
        int2 _14340;
        float3 _16507;
        if (_4597)
        {
            float _14098;
            float _14100;
            _14100 = 2.0f;
            _14098 = -1.0f;
            uint _4170[9];
            float _17075;
            float _17078;
            for (int _14097 = 0; _14097 < 9; _14100 = _17078, _14098 = _17075, _14097++)
            {
                _4170[_14097] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4571 + int2((_14097 % 3) - 1, (_14097 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4170[_14097] != 0u)
                {
                    float _17070;
                    if (_4170[_14097] == 0u)
                    {
                        _17070 = -1.0f;
                    }
                    else
                    {
                        _17070 = float((_4170[_14097] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _17078 = min(_14100, _17070);
                    _17075 = max(_14098, _17070);
                }
                else
                {
                    _17078 = _14100;
                    _17075 = _14098;
                }
            }
            float _4643 = float(_14098 >= 0.0f);
            float3 _13799 = 0.0f.xxx;
            _13799.y = _4643;
            float2 _14118;
            bool _14260;
            int2 _14341;
            float3 _16508;
            if ((_14098 - _14100) > 0.0199999995529651641845703125f)
            {
                float _14106;
                int2 _14107;
                float2 _14108;
                int2 _14110;
                float2 _14116;
                _14116 = _6776;
                _14110 = _4571;
                _14108 = _6776;
                _14107 = _4571;
                _14106 = -1.0f;
                float _17083;
                int2 _17087;
                float2 _17098;
                int2 _17109;
                float2 _17142;
                float _17189;
                int _14105 = 0;
                float _17051 = 1000000000.0f;
                for (; _14105 < 9; _17051 = _17189, _14116 = _17142, _14110 = _17109, _14108 = _17098, _14107 = _17087, _14106 = _17083, _14105++)
                {
                    if (_4170[_14105] == 0u)
                    {
                        _17189 = _17051;
                        _17142 = _14116;
                        _17109 = _14110;
                        _17098 = _14108;
                        _17087 = _14107;
                        _17083 = _14106;
                        continue;
                    }
                    int2 _4678 = clamp(_4571 + int2((_14105 % 3) - 1, (_14105 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6886 = _4170[_14105] & 2147483647u;
                    uint _6918 = uint(max((int((_6886 >> 16u) & 15u) - 6), 0));
                    float2 _4684 = (float2(float((1 - (2 * int((_6886 >> 15u) & 1u))) * int(((_6886 >> uint(7)) & 127u) << _6918)), float((1 - (2 * int((_6886 >> 14u) & 1u))) * int((_6886 & 127u) << _6918))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _17037;
                    if (_4170[_14105] == 0u)
                    {
                        _17037 = -1.0f;
                    }
                    else
                    {
                        _17037 = float((_4170[_14105] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4689 = _17037 - 0.100000001490116119384765625f;
                    float2 _17038;
                    if (_6798)
                    {
                        float2 _6995 = clamp((((_14096 + (_4684 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6998 = tan(_6995.x);
                        _17038 = (float2(_6998 / cbFI_DeviceToViewDepth.z, (tan(_6995.y) * sqrt(1.0f + (_6998 * _6998))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17038 = _14096 + (_4684 * cbFI_Timestep);
                    }
                    float _4696 = cbFI_Timestep - 1.0f;
                    float2 _17039;
                    if (_6798)
                    {
                        float2 _7066 = clamp((((_14096 + (_4684 * _4696)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _7069 = tan(_7066.x);
                        _17039 = (float2(_7069 / cbFI_DeviceToViewDepth.z, (tan(_7066.y) * sqrt(1.0f + (_7069 * _7069))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _17039 = _14096 + (_4684 * _4696);
                    }
                    bool _7102 = all(bool2(_17038.x > 0.0f.xx.x, _17038.y > 0.0f.xx.y));
                    bool _7108;
                    if (_7102)
                    {
                        _7108 = all(bool2(_17038.x < 1.0f.xx.x, _17038.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7108 = _7102;
                    }
                    float _17042;
                    if (_7108)
                    {
                        uint _7115_dummy_parameter;
                        _17042 = max((_4689 - (log((r_depth_tm1.Load(int3(int2(floor(_17038 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7115_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17042 = 0.0f;
                    }
                    bool _7145 = all(bool2(_17039.x > 0.0f.xx.x, _17039.y > 0.0f.xx.y));
                    bool _7151;
                    if (_7145)
                    {
                        _7151 = all(bool2(_17039.x < 1.0f.xx.x, _17039.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7151 = _7145;
                    }
                    float _17043;
                    if (_7151)
                    {
                        uint _7158_dummy_parameter;
                        _17043 = _17042 + max((_4689 - (log((r_depth_tp1.Load(int3(int2(floor(_17039 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7158_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _17043 = _17042;
                    }
                    float _17084;
                    int2 _17088;
                    float2 _17099;
                    int2 _17110;
                    float2 _17143;
                    float _17190;
                    if (_17043 == 0.0f)
                    {
                        bool _4731 = _4689 > _14106;
                        bool2 _17198 = _4731.xx;
                        _17190 = _17051;
                        _17143 = float2(_17198.x ? _4684.x : _14116.x, _17198.y ? _4684.y : _14116.y);
                        _17110 = int2(_17198.x ? _4678.x : _14110.x, _17198.y ? _4678.y : _14110.y);
                        _17099 = _14108;
                        _17088 = _14107;
                        _17084 = _4731 ? _4689 : _14106;
                    }
                    else
                    {
                        bool _4740 = _17043 < _17051;
                        bool2 _17194 = _4740.xx;
                        _17190 = _4740 ? _17043 : _17051;
                        _17143 = _14116;
                        _17110 = _14110;
                        _17099 = float2(_17194.x ? _4684.x : _14108.x, _17194.y ? _4684.y : _14108.y);
                        _17088 = int2(_17194.x ? _4678.x : _14107.x, _17194.y ? _4678.y : _14107.y);
                        _17084 = _14106;
                    }
                    _17189 = _17190;
                    _17142 = _17143;
                    _17109 = _17110;
                    _17098 = _17099;
                    _17087 = _17088;
                    _17083 = _17084;
                }
                bool _4752 = _14106 < 0.0f;
                bool2 _17204 = _4752.xx;
                int2 _17207 = int2(_17204.x ? _14107.x : _14110.x, _17204.y ? _14107.y : _14110.y);
                _16508 = float3(1.0f, _4643, float(any(bool2(_17207.x != _4571.x, _17207.y != _4571.y))));
                _14341 = _17207;
                _14260 = _4752 ? false : true;
                _14118 = float2(_17204.x ? _14108.x : _14116.x, _17204.y ? _14108.y : _14116.y);
            }
            else
            {
                _16508 = _13799;
                _14341 = _4571;
                _14260 = false;
                _14118 = _6776;
            }
            _16507 = _16508;
            _14340 = _14341;
            _14259 = _14260;
            _14117 = _14118;
        }
        else
        {
            _16507 = 0.0f.xxx;
            _14340 = _4571;
            _14259 = false;
            _14117 = _6776;
        }
        float2 _14119;
        if (_6798)
        {
            float2 _7223 = clamp((((_14096 + (_14117 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7226 = tan(_7223.x);
            _14119 = (float2(_7226 / cbFI_DeviceToViewDepth.z, (tan(_7223.y) * sqrt(1.0f + (_7226 * _7226))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14119 = _14096 + (_14117 * cbFI_Timestep);
        }
        float _4775 = cbFI_Timestep - 1.0f;
        float2 _14121;
        if (_6798)
        {
            float2 _7294 = clamp((((_14096 + (_14117 * _4775)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7297 = tan(_7294.x);
            _14121 = (float2(_7297 / cbFI_DeviceToViewDepth.z, (tan(_7294.y) * sqrt(1.0f + (_7297 * _7297))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14121 = _14096 + (_14117 * _4775);
        }
        float _4780 = -cbFI_Timestep;
        float2 _14122;
        if (_6798)
        {
            float2 _7365 = clamp((((_14096 + (_6770 * _4780)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7368 = tan(_7365.x);
            _14122 = (float2(_7368 / cbFI_DeviceToViewDepth.z, (tan(_7365.y) * sqrt(1.0f + (_7368 * _7368))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14122 = _14096 + (_6770 * _4780);
        }
        float _4785 = 1.0f - cbFI_Timestep;
        float2 _14123;
        if (_6798)
        {
            float2 _7436 = clamp((((_14096 + (_6770 * _4785)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7439 = tan(_7436.x);
            _14123 = (float2(_7439 / cbFI_DeviceToViewDepth.z, (tan(_7436.y) * sqrt(1.0f + (_7439 * _7439))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _14123 = _14096 + (_6770 * _4785);
        }
        float4 _7474 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14119, 0.0f);
        float3 _7475 = _7474.xyz;
        float4 _7482 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14121, 0.0f);
        float3 _7483 = _7482.xyz;
        float4 _7490 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _14122, 0.0f);
        float3 _7491 = _7490.xyz;
        float4 _7498 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _14123, 0.0f);
        float3 _7499 = _7498.xyz;
        float4 _7513 = exp(_6764 - max(max(max(_6764.x, _6764.y), _6764.z), _6764.w).xxxx);
        float4 _7520 = _7513 / (dot(_7513, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4801 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _14330;
        float _15638;
        if (_4801)
        {
            float2 _4807 = 0.5f.xx / _4562;
            float _4810 = _4807.x;
            float _4811 = -_4810;
            float _4813 = _4807.y;
            float _4814 = -_4813;
            float2 _4816 = _4560 + float2(_4811, _4814);
            float2 _4818 = float2(cbFI_DisplaySize);
            bool _14140;
            do
            {
                bool _7600 = all(bool2(_4816.x > 0.0f.xx.x, _4816.y > 0.0f.xx.y));
                bool _7606;
                if (_7600)
                {
                    _7606 = all(bool2(_4816.x < 1.0f.xx.x, _4816.y < 1.0f.xx.y));
                }
                else
                {
                    _7606 = _7600;
                }
                if (!_7606)
                {
                    _14140 = false;
                    break;
                }
                uint _7613_dummy_parameter;
                float4x4 _14138;
                do
                {
                    float4x4 _7627;
                    bool _14137;
                    do
                    {
                        _7627 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14137 = false;
                            break;
                        }
                        uint _7661 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7661 + 32u) * 4 + 0) != 1u)
                        {
                            _14137 = false;
                            break;
                        }
                        uint _14134;
                        _14134 = 0u;
                        for (; _14134 < 4u; _14134++)
                        {
                            for (uint _14135 = 0u; _14135 < 4u; )
                            {
                                _7627[_14134][_14135] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7661 + (_14134 * 4u)) + _14135) * 4 + 0));
                                _14135++;
                                continue;
                            }
                        }
                        _14137 = true;
                        break;
                    } while(false);
                    if (_14137)
                    {
                        _14138 = _7627;
                        break;
                    }
                    _14138 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14139;
                do
                {
                    float _7738 = _4816.x;
                    float _7741 = 1.0f - _4816.y;
                    float4 _7752 = mul(float4((float2(_7738, _7741) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4816 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7613_dummy_parameter))))), 0)).x, 1.0f), _14138);
                    float _7754 = _7752.w;
                    if (!(_7754 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14139 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7767 = ((_7752.xy / _7754.xx) + 1.0f.xx) * 0.5f;
                    _14139 = float2(_7767.x - _7738, _7741 - _7767.y);
                    break;
                } while(false);
                float2 _7564 = abs(_14139);
                if (any(bool2(_7564.x > 100000.0f.xx.x, _7564.y > 100000.0f.xx.y)))
                {
                    _14140 = false;
                    break;
                }
                float _7572 = length(_14139 * _4818);
                uint _7787_dummy_parameter;
                bool _7586 = _7572 > ((8.0f * _4818.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7593;
                if (_7586)
                {
                    _7593 = length((r_motion_tp1.Load(int3(int2(floor(_4816 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7787_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4818) < (0.20000000298023223876953125f * _7572);
                }
                else
                {
                    _7593 = _7586;
                }
                _14140 = _7593;
                break;
            } while(false);
            float2 _4828 = _4560 + float2(_4810, _4814);
            bool _14147;
            do
            {
                bool _7873 = all(bool2(_4828.x > 0.0f.xx.x, _4828.y > 0.0f.xx.y));
                bool _7879;
                if (_7873)
                {
                    _7879 = all(bool2(_4828.x < 1.0f.xx.x, _4828.y < 1.0f.xx.y));
                }
                else
                {
                    _7879 = _7873;
                }
                if (!_7879)
                {
                    _14147 = false;
                    break;
                }
                uint _7886_dummy_parameter;
                float4x4 _14145;
                do
                {
                    float4x4 _7900;
                    bool _14144;
                    do
                    {
                        _7900 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14144 = false;
                            break;
                        }
                        uint _7934 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_7934 + 32u) * 4 + 0) != 1u)
                        {
                            _14144 = false;
                            break;
                        }
                        uint _14141;
                        _14141 = 0u;
                        for (; _14141 < 4u; _14141++)
                        {
                            for (uint _14142 = 0u; _14142 < 4u; )
                            {
                                _7900[_14141][_14142] = asfloat(rw_nfru_diagnostics.Load<uint>(((_7934 + (_14141 * 4u)) + _14142) * 4 + 0));
                                _14142++;
                                continue;
                            }
                        }
                        _14144 = true;
                        break;
                    } while(false);
                    if (_14144)
                    {
                        _14145 = _7900;
                        break;
                    }
                    _14145 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14146;
                do
                {
                    float _8011 = _4828.x;
                    float _8014 = 1.0f - _4828.y;
                    float4 _8025 = mul(float4((float2(_8011, _8014) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4828 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7886_dummy_parameter))))), 0)).x, 1.0f), _14145);
                    float _8027 = _8025.w;
                    if (!(_8027 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14146 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8040 = ((_8025.xy / _8027.xx) + 1.0f.xx) * 0.5f;
                    _14146 = float2(_8040.x - _8011, _8014 - _8040.y);
                    break;
                } while(false);
                float2 _7837 = abs(_14146);
                if (any(bool2(_7837.x > 100000.0f.xx.x, _7837.y > 100000.0f.xx.y)))
                {
                    _14147 = false;
                    break;
                }
                float _7845 = length(_14146 * _4818);
                uint _8060_dummy_parameter;
                bool _7859 = _7845 > ((8.0f * _4818.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7866;
                if (_7859)
                {
                    _7866 = length((r_motion_tp1.Load(int3(int2(floor(_4828 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8060_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4818) < (0.20000000298023223876953125f * _7845);
                }
                else
                {
                    _7866 = _7859;
                }
                _14147 = _7866;
                break;
            } while(false);
            float2 _4841 = _4560 + float2(_4811, _4813);
            bool _14154;
            do
            {
                bool _8146 = all(bool2(_4841.x > 0.0f.xx.x, _4841.y > 0.0f.xx.y));
                bool _8152;
                if (_8146)
                {
                    _8152 = all(bool2(_4841.x < 1.0f.xx.x, _4841.y < 1.0f.xx.y));
                }
                else
                {
                    _8152 = _8146;
                }
                if (!_8152)
                {
                    _14154 = false;
                    break;
                }
                uint _8159_dummy_parameter;
                float4x4 _14152;
                do
                {
                    float4x4 _8173;
                    bool _14151;
                    do
                    {
                        _8173 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14151 = false;
                            break;
                        }
                        uint _8207 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8207 + 32u) * 4 + 0) != 1u)
                        {
                            _14151 = false;
                            break;
                        }
                        uint _14148;
                        _14148 = 0u;
                        for (; _14148 < 4u; _14148++)
                        {
                            for (uint _14149 = 0u; _14149 < 4u; )
                            {
                                _8173[_14148][_14149] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8207 + (_14148 * 4u)) + _14149) * 4 + 0));
                                _14149++;
                                continue;
                            }
                        }
                        _14151 = true;
                        break;
                    } while(false);
                    if (_14151)
                    {
                        _14152 = _8173;
                        break;
                    }
                    _14152 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14153;
                do
                {
                    float _8284 = _4841.x;
                    float _8287 = 1.0f - _4841.y;
                    float4 _8298 = mul(float4((float2(_8284, _8287) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4841 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8159_dummy_parameter))))), 0)).x, 1.0f), _14152);
                    float _8300 = _8298.w;
                    if (!(_8300 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14153 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8313 = ((_8298.xy / _8300.xx) + 1.0f.xx) * 0.5f;
                    _14153 = float2(_8313.x - _8284, _8287 - _8313.y);
                    break;
                } while(false);
                float2 _8110 = abs(_14153);
                if (any(bool2(_8110.x > 100000.0f.xx.x, _8110.y > 100000.0f.xx.y)))
                {
                    _14154 = false;
                    break;
                }
                float _8118 = length(_14153 * _4818);
                uint _8333_dummy_parameter;
                bool _8132 = _8118 > ((8.0f * _4818.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8139;
                if (_8132)
                {
                    _8139 = length((r_motion_tp1.Load(int3(int2(floor(_4841 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8333_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4818) < (0.20000000298023223876953125f * _8118);
                }
                else
                {
                    _8139 = _8132;
                }
                _14154 = _8139;
                break;
            } while(false);
            float2 _4853 = _4560 + _4807;
            bool _14161;
            do
            {
                bool _8419 = all(bool2(_4853.x > 0.0f.xx.x, _4853.y > 0.0f.xx.y));
                bool _8425;
                if (_8419)
                {
                    _8425 = all(bool2(_4853.x < 1.0f.xx.x, _4853.y < 1.0f.xx.y));
                }
                else
                {
                    _8425 = _8419;
                }
                if (!_8425)
                {
                    _14161 = false;
                    break;
                }
                uint _8432_dummy_parameter;
                float4x4 _14159;
                do
                {
                    float4x4 _8446;
                    bool _14158;
                    do
                    {
                        _8446 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _14158 = false;
                            break;
                        }
                        uint _8480 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8480 + 32u) * 4 + 0) != 1u)
                        {
                            _14158 = false;
                            break;
                        }
                        uint _14155;
                        _14155 = 0u;
                        for (; _14155 < 4u; _14155++)
                        {
                            for (uint _14156 = 0u; _14156 < 4u; )
                            {
                                _8446[_14155][_14156] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8480 + (_14155 * 4u)) + _14156) * 4 + 0));
                                _14156++;
                                continue;
                            }
                        }
                        _14158 = true;
                        break;
                    } while(false);
                    if (_14158)
                    {
                        _14159 = _8446;
                        break;
                    }
                    _14159 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _14160;
                do
                {
                    float _8557 = _4853.x;
                    float _8560 = 1.0f - _4853.y;
                    float4 _8571 = mul(float4((float2(_8557, _8560) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4853 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8432_dummy_parameter))))), 0)).x, 1.0f), _14159);
                    float _8573 = _8571.w;
                    if (!(_8573 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14160 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8586 = ((_8571.xy / _8573.xx) + 1.0f.xx) * 0.5f;
                    _14160 = float2(_8586.x - _8557, _8560 - _8586.y);
                    break;
                } while(false);
                float2 _8383 = abs(_14160);
                if (any(bool2(_8383.x > 100000.0f.xx.x, _8383.y > 100000.0f.xx.y)))
                {
                    _14161 = false;
                    break;
                }
                float _8391 = length(_14160 * _4818);
                uint _8606_dummy_parameter;
                bool _8405 = _8391 > ((8.0f * _4818.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8412;
                if (_8405)
                {
                    _8412 = length((r_motion_tp1.Load(int3(int2(floor(_4853 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8606_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4818) < (0.20000000298023223876953125f * _8391);
                }
                else
                {
                    _8412 = _8405;
                }
                _14161 = _8412;
                break;
            } while(false);
            float _4859 = 0.25f * (((float(_14140) + float(_14147)) + float(_14154)) + float(_14161));
            float4 _14331;
            if (_4859 < 1.0f)
            {
                bool _14168;
                do
                {
                    bool _8692 = all(bool2(_14119.x > 0.0f.xx.x, _14119.y > 0.0f.xx.y));
                    bool _8698;
                    if (_8692)
                    {
                        _8698 = all(bool2(_14119.x < 1.0f.xx.x, _14119.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8698 = _8692;
                    }
                    if (!_8698)
                    {
                        _14168 = false;
                        break;
                    }
                    uint _8705_dummy_parameter;
                    float4x4 _14166;
                    do
                    {
                        float4x4 _8719;
                        bool _14165;
                        do
                        {
                            _8719 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14165 = false;
                                break;
                            }
                            uint _8753 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_8753 + 32u) * 4 + 0) != 1u)
                            {
                                _14165 = false;
                                break;
                            }
                            uint _14162;
                            _14162 = 0u;
                            for (; _14162 < 4u; _14162++)
                            {
                                for (uint _14163 = 0u; _14163 < 4u; )
                                {
                                    _8719[_14162][_14163] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8753 + (_14162 * 4u)) + _14163) * 4 + 0));
                                    _14163++;
                                    continue;
                                }
                            }
                            _14165 = true;
                            break;
                        } while(false);
                        if (_14165)
                        {
                            _14166 = _8719;
                            break;
                        }
                        _14166 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14167;
                    do
                    {
                        float _8833 = 1.0f - _14119.y;
                        float4 _8844 = mul(float4((float2(_14119.x, _8833) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14119 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8705_dummy_parameter))))), 0)).x, 1.0f), _14166);
                        float _8846 = _8844.w;
                        if (!(_8846 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14167 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8859 = ((_8844.xy / _8846.xx) + 1.0f.xx) * 0.5f;
                        _14167 = float2(_8859.x - _14119.x, _8833 - _8859.y);
                        break;
                    } while(false);
                    float2 _8656 = abs(_14167);
                    if (any(bool2(_8656.x > 100000.0f.xx.x, _8656.y > 100000.0f.xx.y)))
                    {
                        _14168 = false;
                        break;
                    }
                    float _8664 = length(_14167 * _4818);
                    uint _8879_dummy_parameter;
                    bool _8678 = _8664 > ((8.0f * _4818.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8685;
                    if (_8678)
                    {
                        _8685 = length((r_motion_tp1.Load(int3(int2(floor(_14119 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8879_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4818) < (0.20000000298023223876953125f * _8664);
                    }
                    else
                    {
                        _8685 = _8678;
                    }
                    _14168 = _8685;
                    break;
                } while(false);
                bool _14175;
                do
                {
                    bool _8965 = all(bool2(_14121.x > 0.0f.xx.x, _14121.y > 0.0f.xx.y));
                    bool _8971;
                    if (_8965)
                    {
                        _8971 = all(bool2(_14121.x < 1.0f.xx.x, _14121.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8971 = _8965;
                    }
                    if (!_8971)
                    {
                        _14175 = false;
                        break;
                    }
                    uint _8978_dummy_parameter;
                    float4x4 _14173;
                    do
                    {
                        float4x4 _8992;
                        bool _14172;
                        do
                        {
                            _8992 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14172 = false;
                                break;
                            }
                            uint _9026 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9026 + 32u) * 4 + 0) != 1u)
                            {
                                _14172 = false;
                                break;
                            }
                            uint _14169;
                            _14169 = 0u;
                            for (; _14169 < 4u; _14169++)
                            {
                                for (uint _14170 = 0u; _14170 < 4u; )
                                {
                                    _8992[_14169][_14170] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9026 + (_14169 * 4u)) + _14170) * 4 + 0));
                                    _14170++;
                                    continue;
                                }
                            }
                            _14172 = true;
                            break;
                        } while(false);
                        if (_14172)
                        {
                            _14173 = _8992;
                            break;
                        }
                        _14173 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14174;
                    do
                    {
                        float _9106 = 1.0f - _14121.y;
                        float4 _9117 = mul(float4((float2(_14121.x, _9106) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14121 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8978_dummy_parameter))))), 0)).x, 1.0f), _14173);
                        float _9119 = _9117.w;
                        if (!(_9119 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14174 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9132 = ((_9117.xy / _9119.xx) + 1.0f.xx) * 0.5f;
                        _14174 = float2(_9132.x - _14121.x, _9106 - _9132.y);
                        break;
                    } while(false);
                    float2 _8929 = abs(_14174);
                    if (any(bool2(_8929.x > 100000.0f.xx.x, _8929.y > 100000.0f.xx.y)))
                    {
                        _14175 = false;
                        break;
                    }
                    float _8937 = length(_14174 * _4818);
                    uint _9152_dummy_parameter;
                    bool _8951 = _8937 > ((8.0f * _4818.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8958;
                    if (_8951)
                    {
                        _8958 = length((r_motion_tp1.Load(int3(int2(floor(_14121 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9152_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4818) < (0.20000000298023223876953125f * _8937);
                    }
                    else
                    {
                        _8958 = _8951;
                    }
                    _14175 = _8958;
                    break;
                } while(false);
                bool _14182;
                do
                {
                    bool _9238 = all(bool2(_14122.x > 0.0f.xx.x, _14122.y > 0.0f.xx.y));
                    bool _9244;
                    if (_9238)
                    {
                        _9244 = all(bool2(_14122.x < 1.0f.xx.x, _14122.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9244 = _9238;
                    }
                    if (!_9244)
                    {
                        _14182 = false;
                        break;
                    }
                    uint _9251_dummy_parameter;
                    float4x4 _14180;
                    do
                    {
                        float4x4 _9265;
                        bool _14179;
                        do
                        {
                            _9265 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14179 = false;
                                break;
                            }
                            uint _9299 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9299 + 32u) * 4 + 0) != 1u)
                            {
                                _14179 = false;
                                break;
                            }
                            uint _14176;
                            _14176 = 0u;
                            for (; _14176 < 4u; _14176++)
                            {
                                for (uint _14177 = 0u; _14177 < 4u; )
                                {
                                    _9265[_14176][_14177] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9299 + (_14176 * 4u)) + _14177) * 4 + 0));
                                    _14177++;
                                    continue;
                                }
                            }
                            _14179 = true;
                            break;
                        } while(false);
                        if (_14179)
                        {
                            _14180 = _9265;
                            break;
                        }
                        _14180 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14181;
                    do
                    {
                        float _9379 = 1.0f - _14122.y;
                        float4 _9390 = mul(float4((float2(_14122.x, _9379) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14122 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9251_dummy_parameter))))), 0)).x, 1.0f), _14180);
                        float _9392 = _9390.w;
                        if (!(_9392 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14181 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9405 = ((_9390.xy / _9392.xx) + 1.0f.xx) * 0.5f;
                        _14181 = float2(_9405.x - _14122.x, _9379 - _9405.y);
                        break;
                    } while(false);
                    float2 _9202 = abs(_14181);
                    if (any(bool2(_9202.x > 100000.0f.xx.x, _9202.y > 100000.0f.xx.y)))
                    {
                        _14182 = false;
                        break;
                    }
                    float _9210 = length(_14181 * _4818);
                    uint _9425_dummy_parameter;
                    bool _9224 = _9210 > ((8.0f * _4818.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9231;
                    if (_9224)
                    {
                        _9231 = length((r_motion_tp1.Load(int3(int2(floor(_14122 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9425_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4818) < (0.20000000298023223876953125f * _9210);
                    }
                    else
                    {
                        _9231 = _9224;
                    }
                    _14182 = _9231;
                    break;
                } while(false);
                bool _14189;
                do
                {
                    bool _9511 = all(bool2(_14123.x > 0.0f.xx.x, _14123.y > 0.0f.xx.y));
                    bool _9517;
                    if (_9511)
                    {
                        _9517 = all(bool2(_14123.x < 1.0f.xx.x, _14123.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9517 = _9511;
                    }
                    if (!_9517)
                    {
                        _14189 = false;
                        break;
                    }
                    uint _9524_dummy_parameter;
                    float4x4 _14187;
                    do
                    {
                        float4x4 _9538;
                        bool _14186;
                        do
                        {
                            _9538 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14186 = false;
                                break;
                            }
                            uint _9572 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9572 + 32u) * 4 + 0) != 1u)
                            {
                                _14186 = false;
                                break;
                            }
                            uint _14183;
                            _14183 = 0u;
                            for (; _14183 < 4u; _14183++)
                            {
                                for (uint _14184 = 0u; _14184 < 4u; )
                                {
                                    _9538[_14183][_14184] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9572 + (_14183 * 4u)) + _14184) * 4 + 0));
                                    _14184++;
                                    continue;
                                }
                            }
                            _14186 = true;
                            break;
                        } while(false);
                        if (_14186)
                        {
                            _14187 = _9538;
                            break;
                        }
                        _14187 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _14188;
                    do
                    {
                        float _9652 = 1.0f - _14123.y;
                        float4 _9663 = mul(float4((float2(_14123.x, _9652) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_14123 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9524_dummy_parameter))))), 0)).x, 1.0f), _14187);
                        float _9665 = _9663.w;
                        if (!(_9665 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14188 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9678 = ((_9663.xy / _9665.xx) + 1.0f.xx) * 0.5f;
                        _14188 = float2(_9678.x - _14123.x, _9652 - _9678.y);
                        break;
                    } while(false);
                    float2 _9475 = abs(_14188);
                    if (any(bool2(_9475.x > 100000.0f.xx.x, _9475.y > 100000.0f.xx.y)))
                    {
                        _14189 = false;
                        break;
                    }
                    float _9483 = length(_14188 * _4818);
                    uint _9698_dummy_parameter;
                    bool _9497 = _9483 > ((8.0f * _4818.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9504;
                    if (_9497)
                    {
                        _9504 = length((r_motion_tp1.Load(int3(int2(floor(_14123 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9698_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4818) < (0.20000000298023223876953125f * _9483);
                    }
                    else
                    {
                        _9504 = _9497;
                    }
                    _14189 = _9504;
                    break;
                } while(false);
                float4 _4886 = _7520 * float4(_14168 ? 0.0f : 1.0f, _14175 ? 0.0f : 1.0f, _14182 ? 0.0f : 1.0f, _14189 ? 0.0f : 1.0f);
                float _4888 = dot(_4886, 1.0f.xxxx);
                float4 _14332;
                if (_4888 > 0.001000000047497451305389404296875f)
                {
                    _14332 = _4886 / _4888.xxxx;
                }
                else
                {
                    _14332 = _7520;
                }
                _14331 = _14332;
            }
            else
            {
                _14331 = _7520;
            }
            _15638 = _4859;
            _14330 = _14331;
        }
        else
        {
            _15638 = 0.0f;
            _14330 = _7520;
        }
        bool _4905 = _4597 && (!_14259);
        bool _4914;
        if (_4905)
        {
            _4914 = (_14330.z + _14330.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4914 = _4905;
        }
        bool _4925;
        if (_4914)
        {
            _4925 = length((_14122 - _14119) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4925 = _4914;
        }
        bool _14419;
        if (_4925)
        {
            uint4 _9727 = r_warped_motion_qdata_tp1.Load(int3(_14340, 0));
            uint _9728 = _9727.x;
            bool _14422;
            if (_9728 != 0u)
            {
                float _14408;
                if (_9728 == 0u)
                {
                    _14408 = -1.0f;
                }
                else
                {
                    _14408 = float((_9728 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4935 = _14408 - 0.12000000476837158203125f;
                bool _9747 = all(bool2(_14122.x > 0.0f.xx.x, _14122.y > 0.0f.xx.y));
                bool _9753;
                if (_9747)
                {
                    _9753 = all(bool2(_14122.x < 1.0f.xx.x, _14122.y < 1.0f.xx.y));
                }
                else
                {
                    _9753 = _9747;
                }
                bool _4945;
                if (_9753)
                {
                    uint _9760_dummy_parameter;
                    _4945 = (log((r_depth_tm1.Load(int3(int2(floor(_14122 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9760_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4935;
                }
                else
                {
                    _4945 = _9753;
                }
                bool _4959;
                if (!_4945)
                {
                    bool _9790 = all(bool2(_14123.x > 0.0f.xx.x, _14123.y > 0.0f.xx.y));
                    bool _9796;
                    if (_9790)
                    {
                        _9796 = all(bool2(_14123.x < 1.0f.xx.x, _14123.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9796 = _9790;
                    }
                    bool _4957;
                    if (_9796)
                    {
                        uint _9803_dummy_parameter;
                        _4957 = (log((r_depth_tp1.Load(int3(int2(floor(_14123 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9803_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4935;
                    }
                    else
                    {
                        _4957 = _9796;
                    }
                    _4959 = _4957;
                }
                else
                {
                    _4959 = _4945;
                }
                _14422 = _4959;
            }
            else
            {
                _14422 = false;
            }
            _14419 = _14422;
        }
        else
        {
            _14419 = false;
        }
        bool _4964 = _14259 || _14419;
        bool _4969;
        if (_4964)
        {
            bool _9833 = all(bool2(_14119.x > 0.0f.xx.x, _14119.y > 0.0f.xx.y));
            bool _9839;
            if (_9833)
            {
                _9839 = all(bool2(_14119.x < 1.0f.xx.x, _14119.y < 1.0f.xx.y));
            }
            else
            {
                _9839 = _9833;
            }
            _4969 = _9839;
        }
        else
        {
            _4969 = _4964;
        }
        bool _4974;
        if (_4969)
        {
            bool _9844 = all(bool2(_14121.x > 0.0f.xx.x, _14121.y > 0.0f.xx.y));
            bool _9850;
            if (_9844)
            {
                _9850 = all(bool2(_14121.x < 1.0f.xx.x, _14121.y < 1.0f.xx.y));
            }
            else
            {
                _9850 = _9844;
            }
            _4974 = _9850;
        }
        else
        {
            _4974 = _4969;
        }
        float4 _14542;
        if (_4974)
        {
            float _4980 = _14330.x + _14330.y;
            float _4985 = _14330.z + _14330.w;
            float _14437;
            if (_4980 > 0.001000000047497451305389404296875f)
            {
                _14437 = _14330.x / _4980;
            }
            else
            {
                _14437 = _4785;
            }
            _14542 = float4(_14330.x + (_4985 * _14437), _14330.y + (_4985 * (1.0f - _14437)), 0.0f, 0.0f);
        }
        else
        {
            _14542 = _14330;
        }
        bool _9878 = (cbFI_pad0 & 1024u) != 0u;
        bool _9854 = !_9878;
        bool _9855 = !_9854;
        bool _9872;
        if (_9855)
        {
            _9872 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_14340.y * cbFI_MvDepthLaneSize.x) + _14340.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _9872 = _9854;
        }
        bool _9904;
        if (_9855)
        {
            _9904 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4576.y * cbFI_FlowLaneSize.x) + _4576.x)) * 4 + 0) != 0u;
        }
        else
        {
            _9904 = _9854;
        }
        float _5020 = float(_9904);
        bool _14563;
        float4 _14602;
        float3 _16271;
        if (_9878)
        {
            bool _5030;
            if (_9872)
            {
                _5030 = all(bool2(_14119.x > 0.0f.xx.x, _14119.y > 0.0f.xx.y));
            }
            else
            {
                _5030 = _9872;
            }
            bool _5036;
            if (_5030)
            {
                _5036 = all(bool2(_14119.x < 1.0f.xx.x, _14119.y < 1.0f.xx.y));
            }
            else
            {
                _5036 = _5030;
            }
            bool _5043;
            if (_9872)
            {
                _5043 = all(bool2(_14121.x > 0.0f.xx.x, _14121.y > 0.0f.xx.y));
            }
            else
            {
                _5043 = _9872;
            }
            bool _5049;
            if (_5043)
            {
                _5049 = all(bool2(_14121.x < 1.0f.xx.x, _14121.y < 1.0f.xx.y));
            }
            else
            {
                _5049 = _5043;
            }
            bool _5056;
            if (_9904)
            {
                _5056 = all(bool2(_14122.x > 0.0f.xx.x, _14122.y > 0.0f.xx.y));
            }
            else
            {
                _5056 = _9904;
            }
            bool _5062;
            if (_5056)
            {
                _5062 = all(bool2(_14122.x < 1.0f.xx.x, _14122.y < 1.0f.xx.y));
            }
            else
            {
                _5062 = _5056;
            }
            bool _5069;
            if (_9904)
            {
                _5069 = all(bool2(_14123.x > 0.0f.xx.x, _14123.y > 0.0f.xx.y));
            }
            else
            {
                _5069 = _9904;
            }
            bool _5075;
            if (_5069)
            {
                _5075 = all(bool2(_14123.x < 1.0f.xx.x, _14123.y < 1.0f.xx.y));
            }
            else
            {
                _5075 = _5069;
            }
            bool _5077 = !_9872;
            if (_5077)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9946;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _9946);
                }
            }
            bool _5082 = !_9904;
            if (_5082)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9956;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _9956);
                }
            }
            if (_9872 && _5082)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9966;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _9966);
                }
            }
            if (_5077 && _9904)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _9976;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _9976);
                }
            }
            float _5101 = float(_5036);
            float _5103 = float(_5049);
            bool _5106 = _5062 && _5075;
            float _14471;
            if (_5106)
            {
                _14471 = 1.0f;
            }
            else
            {
                _14471 = (_5062 || _5075) ? 0.5f : 0.0f;
            }
            bool _14486;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5036)) && (!_5049))
            {
                bool _5136;
                if (_5106)
                {
                    float _14479;
                    do
                    {
                        bool _10060 = all(bool2(_14122.x > 0.0f.xx.x, _14122.y > 0.0f.xx.y));
                        bool _10066;
                        if (_10060)
                        {
                            _10066 = all(bool2(_14122.x < 1.0f.xx.x, _14122.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _10066 = _10060;
                        }
                        bool _9997 = !_10066;
                        bool _10004;
                        if (!_9997)
                        {
                            bool _10071 = all(bool2(_14123.x > 0.0f.xx.x, _14123.y > 0.0f.xx.y));
                            bool _10077;
                            if (_10071)
                            {
                                _10077 = all(bool2(_14123.x < 1.0f.xx.x, _14123.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _10077 = _10071;
                            }
                            _10004 = !_10077;
                        }
                        else
                        {
                            _10004 = _9997;
                        }
                        if (_10004)
                        {
                            _14479 = 0.0f;
                            break;
                        }
                        uint _10084_dummy_parameter;
                        uint _10100_dummy_parameter;
                        float4x4 _14478;
                        do
                        {
                            float4x4 _10114;
                            bool _14477;
                            do
                            {
                                _10114 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _14477 = false;
                                    break;
                                }
                                uint _10148 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_10148 + 32u) * 4 + 0) != 1u)
                                {
                                    _14477 = false;
                                    break;
                                }
                                uint _14474;
                                _14474 = 0u;
                                for (; _14474 < 4u; _14474++)
                                {
                                    for (uint _14475 = 0u; _14475 < 4u; )
                                    {
                                        _10114[_14474][_14475] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10148 + 16u) + (_14474 * 4u)) + _14475) * 4 + 0));
                                        _14475++;
                                        continue;
                                    }
                                }
                                _14477 = true;
                                break;
                            } while(false);
                            if (_14477)
                            {
                                _14478 = _10114;
                                break;
                            }
                            _14478 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _10025 = mul(float4((float2(_14122.x, 1.0f - _14122.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14122 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10084_dummy_parameter))))), 0)).x, 1.0f), _14478);
                        float _10027 = _10025.w;
                        if (abs(_10027) < 9.9999999747524270787835121154785e-07f)
                        {
                            _14479 = 0.0f;
                            break;
                        }
                        float _10038 = abs(cbFI_DeviceToViewDepth.y / ((_10025.z / _10027) - cbFI_DeviceToViewDepth.x));
                        float _10041 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14123 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10100_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _14479 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_10038 - _10041) / max(max(_10038, _10041), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5136 = _14479 >= 0.5f;
                }
                else
                {
                    _5136 = _5106;
                }
                bool _5144;
                if (_5136)
                {
                    _5144 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5144 = _5136;
                }
                bool _14487;
                if (_5144)
                {
                    uint _10252_dummy_parameter;
                    float4x4 _14484;
                    do
                    {
                        float4x4 _10266;
                        bool _14483;
                        do
                        {
                            _10266 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14483 = false;
                                break;
                            }
                            uint _10300 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10300 + 32u) * 4 + 0) != 1u)
                            {
                                _14483 = false;
                                break;
                            }
                            uint _14480;
                            _14480 = 0u;
                            for (; _14480 < 4u; _14480++)
                            {
                                for (uint _14481 = 0u; _14481 < 4u; )
                                {
                                    _10266[_14480][_14481] = asfloat(rw_nfru_diagnostics.Load<uint>((((_10300 + 16u) + (_14480 * 4u)) + _14481) * 4 + 0));
                                    _14481++;
                                    continue;
                                }
                            }
                            _14483 = true;
                            break;
                        } while(false);
                        if (_14483)
                        {
                            _14484 = _10266;
                            break;
                        }
                        _14484 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _14485;
                    do
                    {
                        float _10380 = 1.0f - _14122.y;
                        float4 _10391 = mul(float4((float2(_14122.x, _10380) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14122 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10252_dummy_parameter))))), 0)).x, 1.0f), _14484);
                        float _10393 = _10391.w;
                        if (!(_10393 > 9.9999999747524270787835121154785e-07f))
                        {
                            _14485 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10406 = ((_10391.xy / _10393.xx) + 1.0f.xx) * 0.5f;
                        _14485 = float2(_10406.x - _14122.x, _10380 - _10406.y);
                        break;
                    } while(false);
                    float2 _5157 = float2(cbFI_DisplaySize);
                    _14487 = length(((_14122 + _14485) - _14123) * _5157) <= ((0.100000001490116119384765625f * length(_14485 * _5157)) + 8.0f);
                }
                else
                {
                    _14487 = _5136;
                }
                _14486 = _14487;
            }
            else
            {
                _14486 = true;
            }
            bool _5171 = !_14486;
            bool _17208 = _5171 ? false : _5075;
            bool _17209 = _5171 ? false : _5062;
            bool _14564;
            float4 _14603;
            if (!(((_5036 && _5049) && _17209) && _17208))
            {
                float4 _5193 = _14542 * float4(_5101, _5103, float(_17209), float(_17208));
                float _5195 = dot(_5193, 1.0f.xxxx);
                bool _5198 = !(_5195 > 0.0f);
                float4 _14604;
                if (!_5198)
                {
                    _14604 = _5193 / _5195.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _10428;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _10428);
                    }
                    _14604 = 0.0f.xxxx;
                }
                _14603 = _14604;
                _14564 = _5198;
            }
            else
            {
                _14603 = _14542;
                _14564 = false;
            }
            _16271 = float3(_5101, _5103, _14471);
            _14602 = _14603;
            _14563 = _14564;
        }
        else
        {
            _16271 = float3(float(_9872), _5020, 0.0f);
            _14602 = _14542;
            _14563 = false;
        }
        bool _5216 = !_14563;
        float4 _14695;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5216)
        {
            float _5223 = _14602.x + _14602.y;
            float4 _14696;
            if (_5223 > 0.001000000047497451305389404296875f)
            {
                _14696 = float4(_14602.x / _5223, _14602.y / _5223, 0.0f, 0.0f);
            }
            else
            {
                _14696 = float4(_4785, cbFI_Timestep, 0.0f, 0.0f);
            }
            _14695 = _14696;
        }
        else
        {
            _14695 = _14602;
        }
        float4 _14872;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5216) && _9872)
        {
            float _14669;
            do
            {
                uint4 _10568 = r_warped_motion_qdata_tp1.Load(int3(_14340, 0));
                uint _10569 = _10568.x;
                if (_10569 != 0u)
                {
                    float _14668;
                    if (_10569 == 0u)
                    {
                        _14668 = -1.0f;
                    }
                    else
                    {
                        _14668 = float((_10569 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14669 = _14668;
                    break;
                }
                int _14651;
                uint _14652;
                _14652 = _10569;
                _14651 = -1;
                uint _14667;
                for (; _14651 <= 1; _14652 = _14667, _14651++)
                {
                    _14667 = _14652;
                    for (int _14665 = -1; _14665 <= 1; )
                    {
                        _14667 = max(_14667, r_warped_motion_qdata_tp1.Load(int3(clamp(_14340 + int2(_14665, _14651), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _14665++;
                        continue;
                    }
                }
                if (_14652 != 0u)
                {
                    float _14664;
                    if (_14652 == 0u)
                    {
                        _14664 = -1.0f;
                    }
                    else
                    {
                        _14664 = float((_14652 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14669 = _14664;
                    break;
                }
                uint _14654;
                _14654 = 4294967295u;
                uint _17179;
                for (int _14653 = 0; _14653 < 8; _14654 = _17179, _14653++)
                {
                    int _14657 = 0;
                    for (;;)
                    {
                        if (_14657 < 5)
                        {
                            int2 _10519 = _14340 + (_1192[_14653] * _1201[_14657].xx);
                            bool _10522 = any(bool2(_10519.x < int2(0, 0).x, _10519.y < int2(0, 0).y));
                            bool _10530;
                            if (!_10522)
                            {
                                _10530 = any(bool2(_10519.x >= cbFI_MvDepthLaneSize.x, _10519.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _10530 = _10522;
                            }
                            if (_10530)
                            {
                                _17179 = _14654;
                                break;
                            }
                            uint4 _10608 = r_warped_motion_qdata_tp1.Load(int3(_10519, 0));
                            uint _10609 = _10608.x;
                            if (_10609 != 0u)
                            {
                                _17179 = min(_14654, _10609);
                                break;
                            }
                            _14657++;
                            continue;
                        }
                        else
                        {
                            _17179 = _14654;
                            break;
                        }
                    }
                }
                float _14656;
                if (_14654 == 4294967295u)
                {
                    _14656 = -1.0f;
                }
                else
                {
                    float _14655;
                    if (_14654 == 0u)
                    {
                        _14655 = -1.0f;
                    }
                    else
                    {
                        _14655 = float((_14654 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14656 = _14655;
                }
                _14669 = _14656;
                break;
            } while(false);
            float _5259 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5262 = r_warped_motion_qdata_tp1.Load(int3(_14340, 0)).x == 0u;
            bool _5268;
            if (_5262)
            {
                bool _10634 = all(bool2(_14119.x > 0.0f.xx.x, _14119.y > 0.0f.xx.y));
                bool _10640;
                if (_10634)
                {
                    _10640 = all(bool2(_14119.x < 1.0f.xx.x, _14119.y < 1.0f.xx.y));
                }
                else
                {
                    _10640 = _10634;
                }
                _5268 = _10640;
            }
            else
            {
                _5268 = _5262;
            }
            bool _5273;
            if (_5268)
            {
                bool _10645 = all(bool2(_14121.x > 0.0f.xx.x, _14121.y > 0.0f.xx.y));
                bool _10651;
                if (_10645)
                {
                    _10651 = all(bool2(_14121.x < 1.0f.xx.x, _14121.y < 1.0f.xx.y));
                }
                else
                {
                    _10651 = _10645;
                }
                _5273 = _10651;
            }
            else
            {
                _5273 = _5268;
            }
            bool _14681;
            float4 _14690;
            if (_5273)
            {
                uint _10658_dummy_parameter;
                float _10682 = log((r_depth_tm1.Load(int3(int2(floor(_14119 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10658_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _10690_dummy_parameter;
                float _10714 = log((r_depth_tp1.Load(int3(int2(floor(_14121 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10690_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _5284 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5291;
                if (_5284)
                {
                    _5291 = _10714 > (_10682 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5291 = _5284;
                }
                bool _14686;
                float4 _14708;
                if (_5291)
                {
                    _14708 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _14686 = true;
                }
                else
                {
                    bool _5297 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5304;
                    if (_5297)
                    {
                        _5304 = _10682 > (_10714 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5304 = _5297;
                    }
                    bool4 _17210 = _5304.xxxx;
                    _14708 = float4(_17210.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14695.x, _17210.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14695.y, _17210.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14695.z, _17210.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14695.w);
                    _14686 = _5304 ? true : false;
                }
                _14690 = _14708;
                _14681 = _14686;
            }
            else
            {
                _14690 = _14695;
                _14681 = false;
            }
            float4 _14763;
            if (_14681)
            {
                _14763 = 1.0f.xxxx;
            }
            else
            {
                bool _5315 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5321;
                if (_5315)
                {
                    _5321 = _14690.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5321 = _5315;
                }
                bool _5326;
                if (_5321)
                {
                    bool _10720 = all(bool2(_14121.x > 0.0f.xx.x, _14121.y > 0.0f.xx.y));
                    bool _10726;
                    if (_10720)
                    {
                        _10726 = all(bool2(_14121.x < 1.0f.xx.x, _14121.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10726 = _10720;
                    }
                    _5326 = _10726;
                }
                else
                {
                    _5326 = _5321;
                }
                float4 _14764;
                if (_5326)
                {
                    float _14717;
                    if (_14669 >= 0.0f)
                    {
                        _14717 = _14669 - _5259;
                    }
                    else
                    {
                        float _14713;
                        _14713 = 2.0f;
                        float _10783;
                        for (int _14712 = 0; _14712 < 24; _14713 = _10783, _14712++)
                        {
                            float _10747 = float(_14712 & 7) * 0.785398185253143310546875f;
                            int _10749 = _14712 >> 3;
                            int _14714;
                            if (_10749 == 0)
                            {
                                _14714 = 16;
                            }
                            else
                            {
                                _14714 = (_10749 == 1) ? 48 : 96;
                            }
                            uint _10815_dummy_parameter;
                            _10783 = min(_14713, log((r_depth_tp1.Load(int3(int2(floor(clamp(_14121 + ((cbFI_MvDepthLaneSizeRcp * float(_14714)) * float2(cos(_10747), sin(_10747))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10815_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _14717 = _14713;
                    }
                    uint _10847_dummy_parameter;
                    float4 _14765;
                    if (r_depth_tp1.Load(int3(int2(floor(_14121 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10847_dummy_parameter))))), 0)).x > ((exp((_14717 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _14765 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _14765 = 1.0f.xxxx;
                    }
                    _14764 = _14765;
                }
                else
                {
                    _14764 = 1.0f.xxxx;
                }
                _14763 = _14764;
            }
            bool _5354 = _14669 >= 0.0f;
            bool _5355 = (!_14681) && _5354;
            bool _5362;
            if (_5355)
            {
                _5362 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5362 = _5355;
            }
            bool _5368;
            if (_5362)
            {
                _5368 = _14690.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5368 = _5362;
            }
            bool _5373;
            if (_5368)
            {
                bool _10871 = all(bool2(_14119.x > 0.0f.xx.x, _14119.y > 0.0f.xx.y));
                bool _10877;
                if (_10871)
                {
                    _10877 = all(bool2(_14119.x < 1.0f.xx.x, _14119.y < 1.0f.xx.y));
                }
                else
                {
                    _10877 = _10871;
                }
                _5373 = _10877;
            }
            else
            {
                _5373 = _5368;
            }
            float4 _14788;
            if (_5373)
            {
                float _14757;
                if (_5354)
                {
                    _14757 = _14669 - _5259;
                }
                else
                {
                    float _14753;
                    _14753 = 2.0f;
                    float _10934;
                    for (int _14752 = 0; _14752 < 24; _14753 = _10934, _14752++)
                    {
                        float _10898 = float(_14752 & 7) * 0.785398185253143310546875f;
                        int _10900 = _14752 >> 3;
                        int _14754;
                        if (_10900 == 0)
                        {
                            _14754 = 16;
                        }
                        else
                        {
                            _14754 = (_10900 == 1) ? 48 : 96;
                        }
                        uint _10950_dummy_parameter;
                        _10934 = min(_14753, log((r_depth_tm1.Load(int3(int2(floor(clamp(_14119 + ((cbFI_MvDepthLaneSizeRcp * float(_14754)) * float2(cos(_10898), sin(_10898))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10950_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _14757 = _14753;
                }
                uint _10998_dummy_parameter;
                float4 _14789;
                if (r_depth_tm1.Load(int3(int2(floor(_14119 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10998_dummy_parameter))))), 0)).x > ((exp((_14757 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _13951 = _14763;
                    _13951.x = 0.0f;
                    _14789 = _13951;
                }
                else
                {
                    _14789 = _14763;
                }
                _14788 = _14789;
            }
            else
            {
                _14788 = _14763;
            }
            float4 _14801;
            if (_5355)
            {
                float _11024 = (exp(((_14669 - _5259) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5411 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5417;
                if (_5411)
                {
                    _5417 = _14690.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5417 = _5411;
                }
                bool _5422;
                if (_5417)
                {
                    bool _11029 = all(bool2(_14123.x > 0.0f.xx.x, _14123.y > 0.0f.xx.y));
                    bool _11035;
                    if (_11029)
                    {
                        _11035 = all(bool2(_14123.x < 1.0f.xx.x, _14123.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11035 = _11029;
                    }
                    _5422 = _11035;
                }
                else
                {
                    _5422 = _5417;
                }
                bool _5430;
                if (_5422)
                {
                    uint _11042_dummy_parameter;
                    _5430 = r_depth_tp1.Load(int3(int2(floor(_14123 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11042_dummy_parameter))))), 0)).x > _11024;
                }
                else
                {
                    _5430 = _5422;
                }
                float4 _14799;
                if (_5430)
                {
                    float4 _13954 = _14788;
                    _13954.w = 0.0f;
                    _14799 = _13954;
                }
                else
                {
                    _14799 = _14788;
                }
                bool _5437 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5443;
                if (_5437)
                {
                    _5443 = _14690.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5443 = _5437;
                }
                bool _5448;
                if (_5443)
                {
                    bool _11059 = all(bool2(_14122.x > 0.0f.xx.x, _14122.y > 0.0f.xx.y));
                    bool _11065;
                    if (_11059)
                    {
                        _11065 = all(bool2(_14122.x < 1.0f.xx.x, _14122.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11065 = _11059;
                    }
                    _5448 = _11065;
                }
                else
                {
                    _5448 = _5443;
                }
                bool _5456;
                if (_5448)
                {
                    uint _11072_dummy_parameter;
                    _5456 = r_depth_tm1.Load(int3(int2(floor(_14122 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11072_dummy_parameter))))), 0)).x > _11024;
                }
                else
                {
                    _5456 = _5448;
                }
                float4 _14802;
                if (_5456)
                {
                    float4 _13957 = _14799;
                    _13957.z = 0.0f;
                    _14802 = _13957;
                }
                else
                {
                    _14802 = _14799;
                }
                _14801 = _14802;
            }
            else
            {
                _14801 = _14788;
            }
            float4 _14873;
            if (any(bool4(_14801.x < 1.0f.xxxx.x, _14801.y < 1.0f.xxxx.y, _14801.z < 1.0f.xxxx.z, _14801.w < 1.0f.xxxx.w)))
            {
                float4 _5467 = _14690 * _14801;
                float _5469 = dot(_5467, 1.0f.xxxx);
                float4 _14874;
                if (_5469 > 0.0f)
                {
                    _14874 = _5467 / _5469.xxxx;
                }
                else
                {
                    bool _5480 = _14801.y == 0.0f;
                    bool _5486;
                    if (_5480)
                    {
                        _5486 = _14801.x > 0.0f;
                    }
                    else
                    {
                        _5486 = _5480;
                    }
                    bool _5491;
                    if (_5486)
                    {
                        bool _11089 = all(bool2(_14119.x > 0.0f.xx.x, _14119.y > 0.0f.xx.y));
                        bool _11095;
                        if (_11089)
                        {
                            _11095 = all(bool2(_14119.x < 1.0f.xx.x, _14119.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11095 = _11089;
                        }
                        _5491 = _11095;
                    }
                    else
                    {
                        _5491 = _5486;
                    }
                    float4 _14875;
                    if (_5491)
                    {
                        _14875 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5496 = _14801.x == 0.0f;
                        bool _5502;
                        if (_5496)
                        {
                            _5502 = _14801.y > 0.0f;
                        }
                        else
                        {
                            _5502 = _5496;
                        }
                        bool _5507;
                        if (_5502)
                        {
                            bool _11100 = all(bool2(_14121.x > 0.0f.xx.x, _14121.y > 0.0f.xx.y));
                            bool _11106;
                            if (_11100)
                            {
                                _11106 = all(bool2(_14121.x < 1.0f.xx.x, _14121.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11106 = _11100;
                            }
                            _5507 = _11106;
                        }
                        else
                        {
                            _5507 = _5502;
                        }
                        bool4 _17213 = _5507.xxxx;
                        _14875 = float4(_17213.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _14690.x, _17213.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _14690.y, _17213.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _14690.z, _17213.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _14690.w);
                    }
                    _14874 = _14875;
                }
                _14873 = _14874;
            }
            else
            {
                _14873 = _14690;
            }
            _14872 = _14873;
        }
        else
        {
            _14872 = _14695;
        }
        float4 _15602;
        bool _15908;
        float3 _16041;
        if (((cbFI_pad0 & 32768u) != 0u) && _5216)
        {
            bool _5524 = _14872.x > 0.00999999977648258209228515625f;
            bool _5527 = _14872.y > 0.00999999977648258209228515625f;
            bool _5536 = (_14872.z + _14872.w) > 0.0199999995529651641845703125f;
            bool _5542;
            if (_5536)
            {
                bool _11111 = all(bool2(_14122.x > 0.0f.xx.x, _14122.y > 0.0f.xx.y));
                bool _11117;
                if (_11111)
                {
                    _11117 = all(bool2(_14122.x < 1.0f.xx.x, _14122.y < 1.0f.xx.y));
                }
                else
                {
                    _11117 = _11111;
                }
                _5542 = _11117;
            }
            else
            {
                _5542 = _5536;
            }
            bool _5547;
            if (_5542)
            {
                bool _11122 = all(bool2(_14123.x > 0.0f.xx.x, _14123.y > 0.0f.xx.y));
                bool _11128;
                if (_11122)
                {
                    _11128 = all(bool2(_14123.x < 1.0f.xx.x, _14123.y < 1.0f.xx.y));
                }
                else
                {
                    _11128 = _11122;
                }
                _5547 = _11128;
            }
            else
            {
                _5547 = _5542;
            }
            bool _5554;
            if (_5547)
            {
                float _14888;
                do
                {
                    bool _11211 = all(bool2(_14122.x > 0.0f.xx.x, _14122.y > 0.0f.xx.y));
                    bool _11217;
                    if (_11211)
                    {
                        _11217 = all(bool2(_14122.x < 1.0f.xx.x, _14122.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11217 = _11211;
                    }
                    bool _11148 = !_11217;
                    bool _11155;
                    if (!_11148)
                    {
                        bool _11222 = all(bool2(_14123.x > 0.0f.xx.x, _14123.y > 0.0f.xx.y));
                        bool _11228;
                        if (_11222)
                        {
                            _11228 = all(bool2(_14123.x < 1.0f.xx.x, _14123.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11228 = _11222;
                        }
                        _11155 = !_11228;
                    }
                    else
                    {
                        _11155 = _11148;
                    }
                    if (_11155)
                    {
                        _14888 = 0.0f;
                        break;
                    }
                    uint _11235_dummy_parameter;
                    uint _11251_dummy_parameter;
                    float4x4 _14887;
                    do
                    {
                        float4x4 _11265;
                        bool _14886;
                        do
                        {
                            _11265 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _14886 = false;
                                break;
                            }
                            uint _11299 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11299 + 32u) * 4 + 0) != 1u)
                            {
                                _14886 = false;
                                break;
                            }
                            uint _14883;
                            _14883 = 0u;
                            for (; _14883 < 4u; _14883++)
                            {
                                for (uint _14884 = 0u; _14884 < 4u; )
                                {
                                    _11265[_14883][_14884] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11299 + 16u) + (_14883 * 4u)) + _14884) * 4 + 0));
                                    _14884++;
                                    continue;
                                }
                            }
                            _14886 = true;
                            break;
                        } while(false);
                        if (_14886)
                        {
                            _14887 = _11265;
                            break;
                        }
                        _14887 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _11176 = mul(float4((float2(_14122.x, 1.0f - _14122.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14122 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11235_dummy_parameter))))), 0)).x, 1.0f), _14887);
                    float _11178 = _11176.w;
                    if (abs(_11178) < 9.9999999747524270787835121154785e-07f)
                    {
                        _14888 = 0.0f;
                        break;
                    }
                    float _11189 = abs(cbFI_DeviceToViewDepth.y / ((_11176.z / _11178) - cbFI_DeviceToViewDepth.x));
                    float _11192 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14123 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11251_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _14888 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11189 - _11192) / max(max(_11189, _11192), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5554 = _14888 < 0.5f;
            }
            else
            {
                _5554 = _5547;
            }
            float4 _14907;
            if (_5554)
            {
                uint _11403_dummy_parameter;
                uint _11434_dummy_parameter;
                float4 _14908;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_14122 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11403_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14123 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11434_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _14908 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _14908 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _14907 = _14908;
            }
            else
            {
                _14907 = 1.0f.xxxx;
            }
            bool _5578;
            if (_9872)
            {
                bool _11463 = all(bool2(_14119.x > 0.0f.xx.x, _14119.y > 0.0f.xx.y));
                bool _11469;
                if (_11463)
                {
                    _11469 = all(bool2(_14119.x < 1.0f.xx.x, _14119.y < 1.0f.xx.y));
                }
                else
                {
                    _11469 = _11463;
                }
                _5578 = _11469;
            }
            else
            {
                _5578 = _9872;
            }
            bool _5584;
            if (_9872)
            {
                bool _11474 = all(bool2(_14121.x > 0.0f.xx.x, _14121.y > 0.0f.xx.y));
                bool _11480;
                if (_11474)
                {
                    _11480 = all(bool2(_14121.x < 1.0f.xx.x, _14121.y < 1.0f.xx.y));
                }
                else
                {
                    _11480 = _11474;
                }
                _5584 = _11480;
            }
            else
            {
                _5584 = _9872;
            }
            bool _5590;
            if (_9904)
            {
                bool _11485 = all(bool2(_14122.x > 0.0f.xx.x, _14122.y > 0.0f.xx.y));
                bool _11491;
                if (_11485)
                {
                    _11491 = all(bool2(_14122.x < 1.0f.xx.x, _14122.y < 1.0f.xx.y));
                }
                else
                {
                    _11491 = _11485;
                }
                _5590 = _11491;
            }
            else
            {
                _5590 = _9904;
            }
            bool _5596;
            if (_9904)
            {
                bool _11496 = all(bool2(_14123.x > 0.0f.xx.x, _14123.y > 0.0f.xx.y));
                bool _11502;
                if (_11496)
                {
                    _11502 = all(bool2(_14123.x < 1.0f.xx.x, _14123.y < 1.0f.xx.y));
                }
                else
                {
                    _11502 = _11496;
                }
                _5596 = _11502;
            }
            else
            {
                _5596 = _9904;
            }
            bool _5599 = _5590 != _5596;
            bool _5605;
            if (_5599)
            {
                _5605 = _5578 || _5584;
            }
            else
            {
                _5605 = _5599;
            }
            float4 _15010;
            if (_5605)
            {
                float4 _13984 = _14907;
                _13984.z = 0.0f;
                _13984.w = 0.0f;
                _15010 = _13984;
            }
            else
            {
                _15010 = _14907;
            }
            bool _5612 = _5578 && _5524;
            bool _5615 = _5584 && _5527;
            float4 _15115;
            float3 _16150;
            if (_5612 || _5615)
            {
                float _15005;
                do
                {
                    uint4 _11641 = r_warped_motion_qdata_tp1.Load(int3(_14340, 0));
                    uint _11642 = _11641.x;
                    if (_11642 != 0u)
                    {
                        float _15004;
                        if (_11642 == 0u)
                        {
                            _15004 = -1.0f;
                        }
                        else
                        {
                            _15004 = float((_11642 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15005 = _15004;
                        break;
                    }
                    int _14987;
                    uint _14988;
                    _14988 = _11642;
                    _14987 = -1;
                    uint _15003;
                    for (; _14987 <= 1; _14988 = _15003, _14987++)
                    {
                        _15003 = _14988;
                        for (int _15001 = -1; _15001 <= 1; )
                        {
                            _15003 = max(_15003, r_warped_motion_qdata_tp1.Load(int3(clamp(_14340 + int2(_15001, _14987), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15001++;
                            continue;
                        }
                    }
                    if (_14988 != 0u)
                    {
                        float _15000;
                        if (_14988 == 0u)
                        {
                            _15000 = -1.0f;
                        }
                        else
                        {
                            _15000 = float((_14988 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15005 = _15000;
                        break;
                    }
                    uint _14990;
                    _14990 = 4294967295u;
                    uint _17180;
                    for (int _14989 = 0; _14989 < 8; _14990 = _17180, _14989++)
                    {
                        int _14993 = 0;
                        for (;;)
                        {
                            if (_14993 < 5)
                            {
                                int2 _11592 = _14340 + (_1192[_14989] * _1201[_14993].xx);
                                bool _11595 = any(bool2(_11592.x < int2(0, 0).x, _11592.y < int2(0, 0).y));
                                bool _11603;
                                if (!_11595)
                                {
                                    _11603 = any(bool2(_11592.x >= cbFI_MvDepthLaneSize.x, _11592.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _11603 = _11595;
                                }
                                if (_11603)
                                {
                                    _17180 = _14990;
                                    break;
                                }
                                uint4 _11681 = r_warped_motion_qdata_tp1.Load(int3(_11592, 0));
                                uint _11682 = _11681.x;
                                if (_11682 != 0u)
                                {
                                    _17180 = min(_14990, _11682);
                                    break;
                                }
                                _14993++;
                                continue;
                            }
                            else
                            {
                                _17180 = _14990;
                                break;
                            }
                        }
                    }
                    float _14992;
                    if (_14990 == 4294967295u)
                    {
                        _14992 = -1.0f;
                    }
                    else
                    {
                        float _14991;
                        if (_14990 == 0u)
                        {
                            _14991 = -1.0f;
                        }
                        else
                        {
                            _14991 = float((_14990 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _14992 = _14991;
                    }
                    _15005 = _14992;
                    break;
                } while(false);
                bool _5623 = _15005 < 0.0f;
                float _15006;
                if (_5623)
                {
                    _15006 = 0.0f;
                }
                else
                {
                    _15006 = _15005 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _11703_dummy_parameter;
                uint _11735_dummy_parameter;
                float4 _15043;
                if ((_5623 && _5612) && _5615)
                {
                    uint _11767_dummy_parameter;
                    float _11791 = log((r_depth_tm1.Load(int3(int2(floor(_14119 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11767_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _11799_dummy_parameter;
                    float _11823 = log((r_depth_tp1.Load(int3(int2(floor(_14121 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11799_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _15044;
                    if (_11791 > (_11823 + 0.07999999821186065673828125f))
                    {
                        float4 _13988 = _15010;
                        _13988.x = 0.0f;
                        _15044 = _13988;
                    }
                    else
                    {
                        float4 _15045;
                        if (_11823 > (_11791 + 0.07999999821186065673828125f))
                        {
                            float4 _13990 = _15010;
                            _13990.y = 0.0f;
                            _15045 = _13990;
                        }
                        else
                        {
                            _15045 = _15010;
                        }
                        _15044 = _15045;
                    }
                    _15043 = _15044;
                }
                else
                {
                    _15043 = _15010;
                }
                float _5675 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5677 = _15005 >= 0.0f;
                float _15026;
                if (_5677)
                {
                    _15026 = _15005 - _5675;
                }
                else
                {
                    float _15022;
                    if (_5612)
                    {
                        float _15021;
                        _15021 = 2.0f;
                        float _11881;
                        for (int _15020 = 0; _15020 < 24; _15021 = _11881, _15020++)
                        {
                            float _11845 = float(_15020 & 7) * 0.785398185253143310546875f;
                            int _11847 = _15020 >> 3;
                            int _15023;
                            if (_11847 == 0)
                            {
                                _15023 = 16;
                            }
                            else
                            {
                                _15023 = (_11847 == 1) ? 48 : 96;
                            }
                            uint _11897_dummy_parameter;
                            _11881 = min(_15021, log((r_depth_tm1.Load(int3(int2(floor(clamp(_14119 + ((cbFI_MvDepthLaneSizeRcp * float(_15023)) * float2(cos(_11845), sin(_11845))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11897_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15022 = _15021;
                    }
                    else
                    {
                        _15022 = 0.0f;
                    }
                    _15026 = _15022;
                }
                float _15033;
                if (_5677)
                {
                    _15033 = _15005 - _5675;
                }
                else
                {
                    float _15029;
                    if (_5615)
                    {
                        float _15028;
                        _15028 = 2.0f;
                        float _11995;
                        for (int _15027 = 0; _15027 < 24; _15028 = _11995, _15027++)
                        {
                            float _11959 = float(_15027 & 7) * 0.785398185253143310546875f;
                            int _11961 = _15027 >> 3;
                            int _15030;
                            if (_11961 == 0)
                            {
                                _15030 = 16;
                            }
                            else
                            {
                                _15030 = (_11961 == 1) ? 48 : 96;
                            }
                            uint _12027_dummy_parameter;
                            _11995 = min(_15028, log((r_depth_tp1.Load(int3(int2(floor(clamp(_14121 + ((cbFI_MvDepthLaneSizeRcp * float(_15030)) * float2(cos(_11959), sin(_11959))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12027_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _15029 = _15028;
                    }
                    else
                    {
                        _15029 = 0.0f;
                    }
                    _15033 = _15029;
                }
                float _15034;
                if (_5612)
                {
                    uint _12059_dummy_parameter;
                    _15034 = r_depth_tm1.Load(int3(int2(floor(_14119 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12059_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15034 = 0.0f;
                }
                float _15035;
                if (_5615)
                {
                    uint _12078_dummy_parameter;
                    _15035 = r_depth_tp1.Load(int3(int2(floor(_14121 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12078_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _15035 = 0.0f;
                }
                bool _5732;
                if (_5612)
                {
                    _5732 = _15034 > ((exp((_15026 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5732 = _5612;
                }
                float4 _15051;
                if (_5732)
                {
                    float4 _13992 = _15043;
                    _13992.x = 0.0f;
                    _15051 = _13992;
                }
                else
                {
                    _15051 = _15043;
                }
                bool _5744;
                if (_5615)
                {
                    _5744 = _15035 > ((exp((_15033 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5744 = _5615;
                }
                float4 _15053;
                if (_5744)
                {
                    float4 _13994 = _15051;
                    _13994.y = 0.0f;
                    _15053 = _13994;
                }
                else
                {
                    _15053 = _15051;
                }
                float4 _15116;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5677)
                {
                    bool _5764;
                    if (_5612)
                    {
                        _5764 = _15034 < ((exp((_15026 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5764 = _5612;
                    }
                    float4 _15055;
                    if (_5764)
                    {
                        float4 _13996 = _15053;
                        _13996.x = 0.0f;
                        _15055 = _13996;
                    }
                    else
                    {
                        _15055 = _15053;
                    }
                    bool _5776;
                    if (_5615)
                    {
                        _5776 = _15035 < ((exp((_15033 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5776 = _5615;
                    }
                    float4 _15117;
                    if (_5776)
                    {
                        float4 _13998 = _15055;
                        _13998.y = 0.0f;
                        _15117 = _13998;
                    }
                    else
                    {
                        _15117 = _15055;
                    }
                    _15116 = _15117;
                }
                else
                {
                    _15116 = _15053;
                }
                _16150 = float3(_15006, log((r_depth_tm1.Load(int3(int2(floor(_14119 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11703_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_14121 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11735_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _15115 = _15116;
            }
            else
            {
                _16150 = float3(0.0f, 0.0f, 0.5f);
                _15115 = _15010;
            }
            bool _5787 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5536;
            bool _5793;
            if (_5787)
            {
                _5793 = _5590 || _5596;
            }
            else
            {
                _5793 = _5787;
            }
            float4 _15158;
            if (_5793)
            {
                float _15110;
                do
                {
                    uint4 _12257 = r_warped_motion_qdata_tp1.Load(int3(_14340, 0));
                    uint _12258 = _12257.x;
                    if (_12258 != 0u)
                    {
                        float _15109;
                        if (_12258 == 0u)
                        {
                            _15109 = -1.0f;
                        }
                        else
                        {
                            _15109 = float((_12258 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15110 = _15109;
                        break;
                    }
                    int _15092;
                    uint _15093;
                    _15093 = _12258;
                    _15092 = -1;
                    uint _15108;
                    for (; _15092 <= 1; _15093 = _15108, _15092++)
                    {
                        _15108 = _15093;
                        for (int _15106 = -1; _15106 <= 1; )
                        {
                            _15108 = max(_15108, r_warped_motion_qdata_tp1.Load(int3(clamp(_14340 + int2(_15106, _15092), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _15106++;
                            continue;
                        }
                    }
                    if (_15093 != 0u)
                    {
                        float _15105;
                        if (_15093 == 0u)
                        {
                            _15105 = -1.0f;
                        }
                        else
                        {
                            _15105 = float((_15093 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15110 = _15105;
                        break;
                    }
                    uint _15095;
                    _15095 = 4294967295u;
                    uint _17181;
                    for (int _15094 = 0; _15094 < 8; _15095 = _17181, _15094++)
                    {
                        int _15098 = 0;
                        for (;;)
                        {
                            if (_15098 < 5)
                            {
                                int2 _12208 = _14340 + (_1192[_15094] * _1201[_15098].xx);
                                bool _12211 = any(bool2(_12208.x < int2(0, 0).x, _12208.y < int2(0, 0).y));
                                bool _12219;
                                if (!_12211)
                                {
                                    _12219 = any(bool2(_12208.x >= cbFI_MvDepthLaneSize.x, _12208.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12219 = _12211;
                                }
                                if (_12219)
                                {
                                    _17181 = _15095;
                                    break;
                                }
                                uint4 _12297 = r_warped_motion_qdata_tp1.Load(int3(_12208, 0));
                                uint _12298 = _12297.x;
                                if (_12298 != 0u)
                                {
                                    _17181 = min(_15095, _12298);
                                    break;
                                }
                                _15098++;
                                continue;
                            }
                            else
                            {
                                _17181 = _15095;
                                break;
                            }
                        }
                    }
                    float _15097;
                    if (_15095 == 4294967295u)
                    {
                        _15097 = -1.0f;
                    }
                    else
                    {
                        float _15096;
                        if (_15095 == 0u)
                        {
                            _15096 = -1.0f;
                        }
                        else
                        {
                            _15096 = float((_15095 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _15097 = _15096;
                    }
                    _15110 = _15097;
                    break;
                } while(false);
                float4 _15159;
                if (_15110 >= 0.0f)
                {
                    float _12319 = (exp((_15110 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5812;
                    if (_5590)
                    {
                        uint _12326_dummy_parameter;
                        _5812 = r_depth_tm1.Load(int3(int2(floor(_14122 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12326_dummy_parameter))))), 0)).x > _12319;
                    }
                    else
                    {
                        _5812 = _5590;
                    }
                    float4 _15128;
                    if (_5812)
                    {
                        float4 _14000 = _15115;
                        _14000.z = 0.0f;
                        _15128 = _14000;
                    }
                    else
                    {
                        _15128 = _15115;
                    }
                    bool _5824;
                    if (_5596)
                    {
                        uint _12345_dummy_parameter;
                        _5824 = r_depth_tp1.Load(int3(int2(floor(_14123 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12345_dummy_parameter))))), 0)).x > _12319;
                    }
                    else
                    {
                        _5824 = _5596;
                    }
                    float4 _15160;
                    if (_5824)
                    {
                        float4 _14002 = _15128;
                        _14002.w = 0.0f;
                        _15160 = _14002;
                    }
                    else
                    {
                        _15160 = _15128;
                    }
                    _15159 = _15160;
                }
                else
                {
                    _15159 = _15115;
                }
                _15158 = _15159;
            }
            else
            {
                _15158 = _15115;
            }
            bool _5832 = _5578 != _5584;
            bool _5839;
            if (_5832)
            {
                _5839 = _5578 ? _5524 : _5527;
            }
            else
            {
                _5839 = _5832;
            }
            bool _5846;
            if (_5839)
            {
                _5846 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5846 = _5839;
            }
            float4 _15261;
            if (_5846)
            {
                bool2 _5851 = _5578.xx;
                float2 _5852 = float2(_5851.x ? _14119.x : _14121.x, _5851.y ? _14119.y : _14121.y);
                float _15142;
                if (_5578)
                {
                    uint _12364_dummy_parameter;
                    _15142 = r_depth_tm1.Load(int3(int2(floor(_5852 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12364_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _12380_dummy_parameter;
                    _15142 = r_depth_tp1.Load(int3(int2(floor(_5852 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12380_dummy_parameter))))), 0)).x;
                }
                float4x4 _15149;
                if (_5578)
                {
                    float4x4 _15138;
                    do
                    {
                        float4x4 _12394;
                        bool _15137;
                        do
                        {
                            _12394 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15137 = false;
                                break;
                            }
                            uint _12428 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12428 + 32u) * 4 + 0) != 1u)
                            {
                                _15137 = false;
                                break;
                            }
                            uint _15134;
                            _15134 = 0u;
                            for (; _15134 < 4u; _15134++)
                            {
                                for (uint _15135 = 0u; _15135 < 4u; )
                                {
                                    _12394[_15134][_15135] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12428 + 16u) + (_15134 * 4u)) + _15135) * 4 + 0));
                                    _15135++;
                                    continue;
                                }
                            }
                            _15137 = true;
                            break;
                        } while(false);
                        if (_15137)
                        {
                            _15138 = _12394;
                            break;
                        }
                        _15138 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _15149 = _15138;
                }
                else
                {
                    float4x4 _15133;
                    do
                    {
                        float4x4 _12500;
                        bool _15132;
                        do
                        {
                            _12500 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _15132 = false;
                                break;
                            }
                            uint _12534 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12534 + 32u) * 4 + 0) != 1u)
                            {
                                _15132 = false;
                                break;
                            }
                            uint _15129;
                            _15129 = 0u;
                            for (; _15129 < 4u; _15129++)
                            {
                                for (uint _15130 = 0u; _15130 < 4u; )
                                {
                                    _12500[_15129][_15130] = asfloat(rw_nfru_diagnostics.Load<uint>(((_12534 + (_15129 * 4u)) + _15130) * 4 + 0));
                                    _15130++;
                                    continue;
                                }
                            }
                            _15132 = true;
                            break;
                        } while(false);
                        if (_15132)
                        {
                            _15133 = _12500;
                            break;
                        }
                        _15133 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _15149 = _15133;
                }
                float2 _15150;
                do
                {
                    float _12611 = _5852.x;
                    float _12614 = 1.0f - _5852.y;
                    float4 _12625 = mul(float4((float2(_12611, _12614) * 2.0f) - 1.0f.xx, _15142, 1.0f), _15149);
                    float _12627 = _12625.w;
                    if (!(_12627 > 9.9999999747524270787835121154785e-07f))
                    {
                        _15150 = 1000000.0f.xx;
                        break;
                    }
                    float2 _12640 = ((_12625.xy / _12627.xx) + 1.0f.xx) * 0.5f;
                    _15150 = float2(_12640.x - _12611, _12614 - _12640.y);
                    break;
                } while(false);
                float2 _5882 = float2(cbFI_DisplaySize);
                float4 _15262;
                if (!(length(((_5852 + _15150) - float2(_5851.x ? _14121.x : _14119.x, _5851.y ? _14121.y : _14119.y)) * _5882) <= ((0.100000001490116119384765625f * length(_15150 * _5882)) + 8.0f)))
                {
                    float4 _15263;
                    if (_5578)
                    {
                        float4 _14012 = _15158;
                        _14012.x = 0.0f;
                        _15263 = _14012;
                    }
                    else
                    {
                        float4 _14014 = _15158;
                        _14014.y = 0.0f;
                        _15263 = _14014;
                    }
                    _15262 = _15263;
                }
                else
                {
                    _15262 = _15158;
                }
                _15261 = _15262;
            }
            else
            {
                _15261 = _15158;
            }
            float4 _5907 = _14872 * _15261;
            float _5909 = dot(_5907, 1.0f.xxxx);
            float4 _15603;
            bool _15909;
            if (_5909 > 0.0f)
            {
                _15909 = _14563;
                _15603 = _5907 / _5909.xxxx;
            }
            else
            {
                bool _5920 = any(bool4(_15261.x < 1.0f.xxxx.x, _15261.y < 1.0f.xxxx.y, _15261.z < 1.0f.xxxx.z, _15261.w < 1.0f.xxxx.w));
                if (_5920)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _12662;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _12662);
                    }
                }
                bool4 _17216 = _5920.xxxx;
                _15909 = _5920 ? true : _14563;
                _15603 = float4(_17216.x ? 0.0f.xxxx.x : _14872.x, _17216.y ? 0.0f.xxxx.y : _14872.y, _17216.z ? 0.0f.xxxx.z : _14872.z, _17216.w ? 0.0f.xxxx.w : _14872.w);
            }
            _16041 = _16150;
            _15908 = _15909;
            _15602 = _15603;
        }
        else
        {
            _16041 = float3(0.0f, 0.0f, 0.5f);
            _15908 = _14563;
            _15602 = _14872;
        }
        uint _5929 = (cbFI_pad0 >> 24u) & 31u;
        uint _5933 = (cbFI_pad0 >> 16u) & 255u;
        bool _5935 = _5929 != 0u;
        bool _5937 = _5933 == 12u;
        bool _5940 = _5933 == 13u;
        float4 _15623;
        if ((_5935 || _5937) || _5940)
        {
            float _15269;
            do
            {
                bool _12746 = all(bool2(_14122.x > 0.0f.xx.x, _14122.y > 0.0f.xx.y));
                bool _12752;
                if (_12746)
                {
                    _12752 = all(bool2(_14122.x < 1.0f.xx.x, _14122.y < 1.0f.xx.y));
                }
                else
                {
                    _12752 = _12746;
                }
                bool _12683 = !_12752;
                bool _12690;
                if (!_12683)
                {
                    bool _12757 = all(bool2(_14123.x > 0.0f.xx.x, _14123.y > 0.0f.xx.y));
                    bool _12763;
                    if (_12757)
                    {
                        _12763 = all(bool2(_14123.x < 1.0f.xx.x, _14123.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12763 = _12757;
                    }
                    _12690 = !_12763;
                }
                else
                {
                    _12690 = _12683;
                }
                if (_12690)
                {
                    _15269 = 0.0f;
                    break;
                }
                uint _12770_dummy_parameter;
                uint _12786_dummy_parameter;
                float4x4 _15268;
                do
                {
                    float4x4 _12800;
                    bool _15267;
                    do
                    {
                        _12800 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _15267 = false;
                            break;
                        }
                        uint _12834 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_12834 + 32u) * 4 + 0) != 1u)
                        {
                            _15267 = false;
                            break;
                        }
                        uint _15264;
                        _15264 = 0u;
                        for (; _15264 < 4u; _15264++)
                        {
                            for (uint _15265 = 0u; _15265 < 4u; )
                            {
                                _12800[_15264][_15265] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12834 + 16u) + (_15264 * 4u)) + _15265) * 4 + 0));
                                _15265++;
                                continue;
                            }
                        }
                        _15267 = true;
                        break;
                    } while(false);
                    if (_15267)
                    {
                        _15268 = _12800;
                        break;
                    }
                    _15268 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _12711 = mul(float4((float2(_14122.x, 1.0f - _14122.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14122 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12770_dummy_parameter))))), 0)).x, 1.0f), _15268);
                float _12713 = _12711.w;
                if (abs(_12713) < 9.9999999747524270787835121154785e-07f)
                {
                    _15269 = 0.0f;
                    break;
                }
                float _12724 = abs(cbFI_DeviceToViewDepth.y / ((_12711.z / _12713) - cbFI_DeviceToViewDepth.x));
                float _12727 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_14123 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12786_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _15269 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12724 - _12727) / max(max(_12724, _12727), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _12936 = all(bool2(_14123.x > 0.0f.xx.x, _14123.y > 0.0f.xx.y));
            bool _12942;
            if (_12936)
            {
                _12942 = all(bool2(_14123.x < 1.0f.xx.x, _14123.y < 1.0f.xx.y));
            }
            else
            {
                _12942 = _12936;
            }
            float _15270;
            if (_12942)
            {
                uint _12949_dummy_parameter;
                _15270 = length((_6770 + (r_motion_tp1.Load(int3(int2(floor(_14123 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _12949_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _15270 = 1000000.0f;
            }
            float _15285;
            if ((_5929 & 1u) != 0u)
            {
                _15285 = _15269;
            }
            else
            {
                _15285 = 1.0f;
            }
            float _15286;
            if ((_5929 & 2u) != 0u)
            {
                _15286 = _15285 * (1.0f - smoothstep(2.0f, 8.0f, _15270));
            }
            else
            {
                _15286 = _15285;
            }
            float _15287;
            if ((_5929 & 4u) != 0u)
            {
                _15287 = _15286 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7491 - _7499) - length(_7475 - _7483))));
            }
            else
            {
                _15287 = _15286;
            }
            float _15617;
            if ((_5929 & 8u) != 0u)
            {
                _15617 = lerp(1.0f, _15287, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7475 - _7483)));
            }
            else
            {
                _15617 = _15287;
            }
            bool _6015 = (_5929 & 16u) != 0u;
            bool _6024;
            if (_6015)
            {
                _6024 = length(_14117 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6024 = _6015;
            }
            float _17218 = _6024 ? 1.0f : _15617;
            bool _6030 = _5935 && _9872;
            bool _6035;
            if (_6030)
            {
                bool _12974 = all(bool2(_14119.x > 0.0f.xx.x, _14119.y > 0.0f.xx.y));
                bool _12980;
                if (_12974)
                {
                    _12980 = all(bool2(_14119.x < 1.0f.xx.x, _14119.y < 1.0f.xx.y));
                }
                else
                {
                    _12980 = _12974;
                }
                _6035 = _12980;
            }
            else
            {
                _6035 = _6030;
            }
            bool _6040;
            if (_6035)
            {
                bool _12985 = all(bool2(_14121.x > 0.0f.xx.x, _14121.y > 0.0f.xx.y));
                bool _12991;
                if (_12985)
                {
                    _12991 = all(bool2(_14121.x < 1.0f.xx.x, _14121.y < 1.0f.xx.y));
                }
                else
                {
                    _12991 = _12985;
                }
                _6040 = _12991;
            }
            else
            {
                _6040 = _6035;
            }
            float4 _15624;
            if (_6040)
            {
                float _6046 = _15602.x + _15602.y;
                float _6055 = (_15602.z + _15602.w) * (1.0f - _17218);
                float _15620;
                if (_6046 > 9.9999997473787516355514526367188e-06f)
                {
                    _15620 = _15602.x / _6046;
                }
                else
                {
                    _15620 = _4785;
                }
                _15624 = float4(_15602.x + (_6055 * _15620), _15602.y + (_6055 * (1.0f - _15620)), _15602.zw * _17218);
            }
            else
            {
                _15624 = _15602;
            }
            _15623 = _15624;
        }
        else
        {
            _15623 = _15602;
        }
        float3 _6116 = (((_7475 * _15623.x) + (_7483 * _15623.y)) + (_7491 * _15623.z)) + (_7499 * _15623.w);
        float3 _16983;
        if (_4801 && (_15638 > 0.0f))
        {
            uint _12998_dummy_parameter;
            float2 _13013 = r_motion_tp1.Load(int3(int2(floor(_4560 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _12998_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _15900;
            if (_6798)
            {
                float2 _13058 = clamp((((_14096 + (_13013 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13061 = tan(_13058.x);
                _15900 = (float2(_13061 / cbFI_DeviceToViewDepth.z, (tan(_13058.y) * sqrt(1.0f + (_13061 * _13061))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15900 = _14096 + (_13013 * cbFI_Timestep);
            }
            float2 _15901;
            if (_6798)
            {
                float2 _13137 = clamp((((_14096 + (_13013 * _4775)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _13140 = tan(_13137.x);
                _15901 = (float2(_13140 / cbFI_DeviceToViewDepth.z, (tan(_13137.y) * sqrt(1.0f + (_13140 * _13140))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _15901 = _14096 + (_13013 * _4775);
            }
            _16983 = lerp(_6116, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _15900, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _15901, 0.0f).xyz, cbFI_Timestep.xxx), _15638.xxx);
        }
        else
        {
            _16983 = _6116;
        }
        float3 _16982;
        if (_15908)
        {
            float3 _13182 = r_current_interpolation_source.Load(int3(_4086, 0)).xyz;
            float3 _16984;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _9872)
            {
                uint _13189_dummy_parameter;
                float _16031;
                _16031 = r_depth_tm1.Load(int3(int2(floor(_14119 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13189_dummy_parameter))))), 0)).x;
                float _6197;
                for (int _16030 = 0; _16030 < 24; _16031 = _6197, _16030++)
                {
                    float _6169 = float(_16030 & 7) * 0.785398185253143310546875f;
                    int _6171 = _16030 >> 3;
                    int _17034;
                    if (_6171 == 0)
                    {
                        _17034 = 16;
                    }
                    else
                    {
                        _17034 = (_6171 == 1) ? 48 : 96;
                    }
                    uint _13209_dummy_parameter;
                    _6197 = min(_16031, r_depth_tm1.Load(int3(int2(floor(clamp(_14119 + ((cbFI_MvDepthLaneSizeRcp * float(_17034)) * float2(cos(_6169), sin(_6169))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13209_dummy_parameter))))), 0)).x);
                }
                float2 _16032;
                do
                {
                    float _13231 = 1.0f - _14119.y;
                    float4 _13242 = mul(float4((float2(_14119.x, _13231) * 2.0f) - 1.0f.xx, _16031, 1.0f), cbFI_MotionTM1ToTM2);
                    float _13244 = _13242.w;
                    if (!(_13244 > 9.9999999747524270787835121154785e-07f))
                    {
                        _16032 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13257 = ((_13242.xy / _13244.xx) + 1.0f.xx) * 0.5f;
                    _16032 = float2(_13257.x - _14119.x, _13231 - _13257.y);
                    break;
                } while(false);
                float2 _6208 = _14119 + _16032;
                bool _13275 = all(bool2(_6208.x > 0.0f.xx.x, _6208.y > 0.0f.xx.y));
                bool _13281;
                if (_13275)
                {
                    _13281 = all(bool2(_6208.x < 1.0f.xx.x, _6208.y < 1.0f.xx.y));
                }
                else
                {
                    _13281 = _13275;
                }
                float3 _16985;
                if (_13281)
                {
                    float _6214 = abs(cbFI_DeviceToViewDepth.y / (_16031 - cbFI_DeviceToViewDepth.x));
                    uint _13301_dummy_parameter;
                    int2 _13301 = int2(spvTextureSize(r_depth_m2, uint(0), _13301_dummy_parameter));
                    float _6218 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6208 * float2(_13301))), int2(0, 0), _13301 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _16990;
                    if (abs(_6218 - _6214) <= (0.20000000298023223876953125f * max(_6218, _6214)))
                    {
                        uint _13335_dummy_parameter;
                        int2 _13335 = int2(spvTextureSize(r_colour_m2, uint(0), _13335_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13358;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _13358);
                        }
                        _16990 = r_colour_m2.Load(int3(clamp(int2(floor(_6208 * float2(_13335))), int2(0, 0), _13335 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _13368;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13368);
                        }
                        _16990 = _13182;
                    }
                    _16985 = _16990;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13378;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _13378);
                    }
                    _16985 = _13182;
                }
                _16984 = _16985;
            }
            else
            {
                _16984 = _13182;
            }
            _16982 = _16984;
        }
        else
        {
            _16982 = _16983;
        }
        uint _6246 = cbFI_pad0 & 255u;
        bool _16859;
        float3 _16981;
        if (_6246 != 0u)
        {
            float3 _6251 = r_present_backbuffer.Load(int3(_4086, 0)).xyz;
            float3 _6255 = r_current_interpolation_source.Load(int3(_4086, 0)).xyz;
            float3 _6259 = abs(_6251 - _6255);
            float3 _16035;
            if (_6246 == 2u)
            {
                _16035 = (abs(_6255) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _16035 = 0.000244140625f.xxx;
            }
            bool _6275 = any(bool3(_6259.x > _16035.x, _6259.y > _16035.y, _6259.z > _16035.z));
            bool3 _17219 = _6275.xxx;
            _16981 = float3(_17219.x ? _6251.x : _16982.x, _17219.y ? _6251.y : _16982.y, _17219.z ? _6251.z : _16982.z);
            _16859 = _6275;
        }
        else
        {
            _16981 = _16982;
            _16859 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _13393;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _13393);
        }
        float3 _16964;
        if (_5933 == 1u)
        {
            _16964 = lerp(_7475, _7483, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _16965;
            if (_5933 == 2u)
            {
                _16965 = lerp(_7491, _7499, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _16966;
                if (_5933 == 3u)
                {
                    _16966 = float(_16859).xxx;
                }
                else
                {
                    float3 _16967;
                    if (_5933 == 4u)
                    {
                        _16967 = float3(((_14117 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _16968;
                        if (_5933 == 5u)
                        {
                            _16968 = float3(((_6770 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _16969;
                            if (_5933 == 6u)
                            {
                                _16969 = float3(_15623.xy, _15623.z + _15623.w);
                            }
                            else
                            {
                                float3 _16970;
                                if (_5933 == 7u)
                                {
                                    _16970 = r_current_interpolation_source.Load(int3(_4086, 0)).xyz;
                                }
                                else
                                {
                                    float3 _16971;
                                    if (_5933 == 8u)
                                    {
                                        _16971 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4560, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _16972;
                                        if (_5937)
                                        {
                                            uint _13415_dummy_parameter;
                                            uint _13447_dummy_parameter;
                                            _16972 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4560 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13415_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4560 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13447_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _16973;
                                            if (_5940)
                                            {
                                                _16973 = _7491;
                                            }
                                            else
                                            {
                                                float3 _16974;
                                                if (_5933 == 20u)
                                                {
                                                    _16974 = _7475;
                                                }
                                                else
                                                {
                                                    float3 _16975;
                                                    if (_5933 == 21u)
                                                    {
                                                        _16975 = _7483;
                                                    }
                                                    else
                                                    {
                                                        float3 _16976;
                                                        if (_5933 == 22u)
                                                        {
                                                            _16976 = _7499;
                                                        }
                                                        else
                                                        {
                                                            float3 _16977;
                                                            if (_5933 == 18u)
                                                            {
                                                                _16977 = _16507;
                                                            }
                                                            else
                                                            {
                                                                float3 _16978;
                                                                if (_5933 == 19u)
                                                                {
                                                                    _16978 = _16271;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _17221 = (_5933 == 23u).xxx;
                                                                    _16978 = float3(_17221.x ? _16041.x : _16981.x, _17221.y ? _16041.y : _16981.y, _17221.z ? _16041.z : _16981.z);
                                                                }
                                                                _16977 = _16978;
                                                            }
                                                            _16976 = _16977;
                                                        }
                                                        _16975 = _16976;
                                                    }
                                                    _16974 = _16975;
                                                }
                                                _16973 = _16974;
                                            }
                                            _16972 = _16973;
                                        }
                                        _16971 = _16972;
                                    }
                                    _16970 = _16971;
                                }
                                _16969 = _16970;
                            }
                            _16968 = _16969;
                        }
                        _16967 = _16968;
                    }
                    _16966 = _16967;
                }
                _16965 = _16966;
            }
            _16964 = _16965;
        }
        float3 _16963;
        if ((_5933 >= 9u) && (_5933 <= 11u))
        {
            uint _6439 = 64u + uint((_14340.y * cbFI_MvDepthLaneSize.x) + _14340.x);
            uint _6443 = rw_nfru_diagnostics.Load<uint>(_6439 * 4 + 0) & 15u;
            float3 _16995;
            if (_5933 == 10u)
            {
                float3 _16962;
                if ((rw_nfru_diagnostics.Load<uint>(_6439 * 4 + 0) & 32u) != 0u)
                {
                    _16962 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _16961;
                    if ((rw_nfru_diagnostics.Load<uint>(_6439 * 4 + 0) & 16u) != 0u)
                    {
                        _16961 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6464 = ((rw_nfru_diagnostics.Load<uint>(_6439 * 4 + 0) & 64u) != 0u).xxx;
                        _16961 = float3(_6464.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6464.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6464.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _16962 = _16961;
                }
                _16995 = _16962;
            }
            else
            {
                float3 _16996;
                if (_5933 == 11u)
                {
                    uint _6477 = (rw_nfru_diagnostics.Load<uint>(_6439 * 4 + 0) >> 8u) & 15u;
                    uint _6480 = (rw_nfru_diagnostics.Load<uint>(_6439 * 4 + 0) >> 12u) & 15u;
                    float3 _16954;
                    if ((_6443 == 2u) || (_6443 == 3u))
                    {
                        _16954 = _3782[_6443];
                    }
                    else
                    {
                        bool _6492 = _6477 == 3u;
                        bool _6494 = _6480 == 3u;
                        float3 _16955;
                        if (_6492 && _6494)
                        {
                            _16955 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _16956;
                            if (_6492)
                            {
                                _16956 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _16957;
                                if (_6494)
                                {
                                    _16957 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _16958;
                                    if ((_6477 == 4u) || (_6480 == 4u))
                                    {
                                        _16958 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _16959;
                                        if ((_6477 == 1u) || (_6480 == 1u))
                                        {
                                            _16959 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _17223 = (_6443 == 1u).xxx;
                                            _16959 = float3(_17223.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _17223.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _17223.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _16958 = _16959;
                                    }
                                    _16957 = _16958;
                                }
                                _16956 = _16957;
                            }
                            _16955 = _16956;
                        }
                        _16954 = _16955;
                    }
                    _16996 = _16954;
                }
                else
                {
                    _16996 = _3782[min(_6443, 7u)];
                }
                _16995 = _16996;
            }
            _16963 = _16995;
        }
        else
        {
            _16963 = _16964;
        }
        float4 _16999;
        if ((_5933 >= 14u) && (_5933 <= 16u))
        {
            float2 _16997;
            if (_5933 == 14u)
            {
                uint _6550_dummy_parameter;
                uint _6556_dummy_parameter;
                _16997 = r_flow_tm1.Load(int3(clamp(int2(floor(_4560 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6550_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6556_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _16998;
                if (_5933 == 16u)
                {
                    uint _13498 = r_warped_flow_qdata_tm1.Load(int3(_4576, 0)).x & 2147483647u;
                    uint _13530 = uint(max((int((_13498 >> 16u) & 15u) - 6), 0));
                    _16998 = ((float2(float((1 - (2 * int((_13498 >> 15u) & 1u))) * int(((_13498 >> uint(7)) & 127u) << _13530)), float((1 - (2 * int((_13498 >> 14u) & 1u))) * int((_13498 & 127u) << _13530))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _16998 = _6770 * float2(cbFI_DisplaySize);
                }
                _16997 = _16998;
            }
            uint2 _6589 = uint2(clamp(round(_16997 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6591 = _6589.x;
            uint _6598 = _6589.y;
            _16999 = float4(float(_6591 & 255u), float((_6591 >> 8u) | ((_6598 & 15u) << 4u)), float(_6598 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _17000;
            if (_5933 == 17u)
            {
                _17000 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4576, 0)).x != 0u), _5020, 0.0f, 1.0f);
            }
            else
            {
                _17000 = float4(_16963, 1.0f);
            }
            _16999 = _17000;
        }
        rw_output[_4086] = _16999.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6642 = ((uint(_4086.y) * uint(cbFI_DisplaySize.x)) + uint(_4086.x)) * 6u;
            uint _13576 = spvPackHalf2x16(clamp(_7474.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6642 * 4 + 0, (((_13576 & 32767u) >> 4u) | ((((_13576 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7474.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13611 = spvPackHalf2x16(clamp(_7482.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6642 + 1u) * 4 + 0, (((_13611 & 32767u) >> 4u) | ((((_13611 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7482.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13646 = spvPackHalf2x16(clamp(_7490.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6642 + 2u) * 4 + 0, (((_13646 & 32767u) >> 4u) | ((((_13646 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7490.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _13681 = spvPackHalf2x16(clamp(_7498.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6642 + 3u) * 4 + 0, (((_13681 & 32767u) >> 4u) | ((((_13681 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7498.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _13708 = r_current_interpolation_source.Load(int3(_4086, 0));
            uint _13722 = spvPackHalf2x16(clamp(_13708.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6642 + 4u) * 4 + 0, (((_13722 & 32767u) >> 4u) | ((((_13722 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_13708.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _17033;
            if (_16859 || (_5933 != 0u))
            {
                _17033 = 4294967295u;
            }
            else
            {
                uint _13757 = spvPackHalf2x16(clamp(_16999.xy, 0.0f.xx, 65000.0f.xx));
                _17033 = (((_13757 & 32767u) >> 4u) | ((((_13757 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_16999.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6642 + 5u) * 4 + 0, _17033);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4086] = float4(r_current_interpolation_source.Load(int3(_4086, 0)).xyz, 1.0f).xyz;
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
