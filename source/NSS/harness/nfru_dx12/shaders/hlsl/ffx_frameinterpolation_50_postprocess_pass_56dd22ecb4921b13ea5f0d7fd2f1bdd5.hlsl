static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19666;

static const int2 _1239[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1248[5] = { 2, 4, 7, 11, 16 };
static const float3 _4520[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4821 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4821.x >= cbFI_DisplaySize.x, _4821.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4821] = float4(r_present_backbuffer.Load(int3(_4821, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7664 = cbFI_DisplaySize - int2(1, 1);
                int2 _7665 = clamp(_4821, int2(0, 0), _7664);
                uint _7675 = uint((_7665.y * cbFI_DisplaySize.x) + _7665.x) * 2u;
                uint _7678 = rw_nfru_select.Load<uint>(_7675 * 4 + 0);
                float2 _7679 = spvUnpackHalf2x16(_7678);
                uint _7683 = rw_nfru_select.Load<uint>((_7675 + 1u) * 4 + 0);
                float2 _7684 = spvUnpackHalf2x16(_7683);
                float _7685 = _7679.x;
                float _7687 = _7684.x;
                if (_7684.y > 1.5f)
                {
                    rw_output[_4821] = float4(_7685, _7679.y, _7687, 1.0f).xyz;
                    break;
                }
                int _23096;
                float _23097;
                float3 _23098;
                float _23099;
                float _23100;
                _23100 = 0.0f;
                _23099 = 0.0f;
                _23098 = 0.0f.xxx;
                _23097 = 0.0f;
                _23096 = -2;
                float3 _23103;
                float _23104;
                float _23105;
                float _23106;
                for (; _23096 <= 2; _23100 = _23106, _23099 = _23105, _23098 = _23103, _23097 = _23104, _23096++)
                {
                    _23106 = _23100;
                    _23105 = _23099;
                    _23104 = _23097;
                    _23103 = _23098;
                    for (int _23101 = -2; _23101 <= 2; )
                    {
                        float _7581 = float((_23101 * _23101) + (_23096 * _23096));
                        float _7586 = exp(_7581 * (-0.319999992847442626953125f));
                        int2 _7591 = int2(_23101, _23096);
                        int2 _7701 = clamp(_4821 + (_7591 * int2(2, 2)), int2(0, 0), _7664);
                        uint _7711 = uint((_7701.y * cbFI_DisplaySize.x) + _7701.x) * 2u;
                        float _7608 = exp(_7581 * (-0.5f));
                        int2 _7733 = clamp(_4821 + (_7591 * int2(6, 6)), int2(0, 0), _7664);
                        _23106 += _7608;
                        _23105 += (_7608 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7733.y * cbFI_DisplaySize.x) + _7733.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23104 += _7586;
                        _23103 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7711 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7711 + 1u) * 4 + 0)).x, _19666).xyz * _7586);
                        _23101++;
                        continue;
                    }
                }
                float3 _7638 = _23098 / _23097.xxx;
                rw_output[_4821] = float4(_7638 + ((float4(_7685, _7679.y, _7687, _7684.y).xyz - _7638) * clamp(_23099 / _23100, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5314 = (float2(_4821) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5316 = float2(cbFI_MvDepthLaneSize);
        int2 _5325 = int2(floor(_5314 * _5316));
        int2 _5330 = int2(floor(_5314 * float2(cbFI_FlowLaneSize)));
        float4 _7804 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5314 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7810 = r_warped_filled_flow_tm1.Load(int3(_5330, 0)).xy;
        float2 _7816 = r_warped_filled_motion_tp1.Load(int3(_5325, 0)).xy;
        bool _7838 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19667;
        if (_7838)
        {
            float _7851 = ((2.0f * _5314.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19667 = float2(atan(_7851) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5314.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7851 * _7851))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19667 = _5314;
        }
        bool _5351 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19688;
        bool _19830;
        int2 _19911;
        float3 _22192;
        if (_5351)
        {
            float _19669;
            float _19671;
            _19671 = 2.0f;
            _19669 = -1.0f;
            uint _4913[9];
            float _23107;
            float _23110;
            for (int _19668 = 0; _19668 < 9; _19671 = _23110, _19669 = _23107, _19668++)
            {
                _4913[_19668] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5325 + int2((_19668 % 3) - 1, (_19668 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4913[_19668] != 0u)
                {
                    float _23091;
                    if (_4913[_19668] == 0u)
                    {
                        _23091 = -1.0f;
                    }
                    else
                    {
                        _23091 = float((_4913[_19668] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23110 = min(_19671, _23091);
                    _23107 = max(_19669, _23091);
                }
                else
                {
                    _23110 = _19671;
                    _23107 = _19669;
                }
            }
            float _5397 = float(_19669 >= 0.0f);
            float3 _19234 = 0.0f.xxx;
            _19234.y = _5397;
            float2 _19689;
            bool _19831;
            int2 _19912;
            float3 _22193;
            if ((_19669 - _19671) > 0.0199999995529651641845703125f)
            {
                float _19677;
                int2 _19678;
                float2 _19679;
                int2 _19681;
                float2 _19687;
                _19687 = _7816;
                _19681 = _5325;
                _19679 = _7816;
                _19678 = _5325;
                _19677 = -1.0f;
                float _23115;
                int2 _23119;
                float2 _23130;
                int2 _23141;
                float2 _23174;
                float _23559;
                int _19676 = 0;
                float _23072 = 1000000000.0f;
                for (; _19676 < 9; _23072 = _23559, _19687 = _23174, _19681 = _23141, _19679 = _23130, _19678 = _23119, _19677 = _23115, _19676++)
                {
                    if (_4913[_19676] == 0u)
                    {
                        _23559 = _23072;
                        _23174 = _19687;
                        _23141 = _19681;
                        _23130 = _19679;
                        _23119 = _19678;
                        _23115 = _19677;
                        continue;
                    }
                    int2 _5432 = clamp(_5325 + int2((_19676 % 3) - 1, (_19676 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _7926 = _4913[_19676] & 2147483647u;
                    uint _7958 = uint(max((int((_7926 >> 16u) & 15u) - 6), 0));
                    float2 _5438 = (float2(float((1 - (2 * int((_7926 >> 15u) & 1u))) * int(((_7926 >> uint(7)) & 127u) << _7958)), float((1 - (2 * int((_7926 >> 14u) & 1u))) * int((_7926 & 127u) << _7958))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23058;
                    if (_4913[_19676] == 0u)
                    {
                        _23058 = -1.0f;
                    }
                    else
                    {
                        _23058 = float((_4913[_19676] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5443 = _23058 - 0.100000001490116119384765625f;
                    float2 _23059;
                    if (_7838)
                    {
                        float2 _8035 = clamp((((_19667 + (_5438 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8038 = tan(_8035.x);
                        _23059 = (float2(_8038 / cbFI_DeviceToViewDepth.z, (tan(_8035.y) * sqrt(1.0f + (_8038 * _8038))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23059 = _19667 + (_5438 * cbFI_Timestep);
                    }
                    float _5450 = cbFI_Timestep - 1.0f;
                    float2 _23060;
                    if (_7838)
                    {
                        float2 _8106 = clamp((((_19667 + (_5438 * _5450)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8109 = tan(_8106.x);
                        _23060 = (float2(_8109 / cbFI_DeviceToViewDepth.z, (tan(_8106.y) * sqrt(1.0f + (_8109 * _8109))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23060 = _19667 + (_5438 * _5450);
                    }
                    bool _8142 = all(bool2(_23059.x > 0.0f.xx.x, _23059.y > 0.0f.xx.y));
                    bool _8148;
                    if (_8142)
                    {
                        _8148 = all(bool2(_23059.x < 1.0f.xx.x, _23059.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8148 = _8142;
                    }
                    float _23063;
                    if (_8148)
                    {
                        uint _8155_dummy_parameter;
                        _23063 = max((_5443 - (log(((r_depth_tm1.Load(int3(int2(floor(_23059 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8155_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23063 = 0.0f;
                    }
                    bool _8185 = all(bool2(_23060.x > 0.0f.xx.x, _23060.y > 0.0f.xx.y));
                    bool _8191;
                    if (_8185)
                    {
                        _8191 = all(bool2(_23060.x < 1.0f.xx.x, _23060.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8191 = _8185;
                    }
                    float _23064;
                    if (_8191)
                    {
                        uint _8198_dummy_parameter;
                        _23064 = _23063 + max((_5443 - (log(((r_depth_tp1.Load(int3(int2(floor(_23060 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8198_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23064 = _23063;
                    }
                    float _23116;
                    int2 _23120;
                    float2 _23131;
                    int2 _23142;
                    float2 _23175;
                    float _23560;
                    if (_23064 == 0.0f)
                    {
                        bool _5485 = _5443 > _19677;
                        bool2 _23568 = _5485.xx;
                        _23560 = _23072;
                        _23175 = float2(_23568.x ? _5438.x : _19687.x, _23568.y ? _5438.y : _19687.y);
                        _23142 = int2(_23568.x ? _5432.x : _19681.x, _23568.y ? _5432.y : _19681.y);
                        _23131 = _19679;
                        _23120 = _19678;
                        _23116 = _5485 ? _5443 : _19677;
                    }
                    else
                    {
                        bool _5494 = _23064 < _23072;
                        bool2 _23564 = _5494.xx;
                        _23560 = _5494 ? _23064 : _23072;
                        _23175 = _19687;
                        _23142 = _19681;
                        _23131 = float2(_23564.x ? _5438.x : _19679.x, _23564.y ? _5438.y : _19679.y);
                        _23120 = int2(_23564.x ? _5432.x : _19678.x, _23564.y ? _5432.y : _19678.y);
                        _23116 = _19677;
                    }
                    _23559 = _23560;
                    _23174 = _23175;
                    _23141 = _23142;
                    _23130 = _23131;
                    _23119 = _23120;
                    _23115 = _23116;
                }
                bool _5506 = _19677 < 0.0f;
                bool2 _23574 = _5506.xx;
                int2 _23577 = int2(_23574.x ? _19678.x : _19681.x, _23574.y ? _19678.y : _19681.y);
                _22193 = float3(1.0f, _5397, float(any(bool2(_23577.x != _5325.x, _23577.y != _5325.y))));
                _19912 = _23577;
                _19831 = _5506 ? false : true;
                _19689 = float2(_23574.x ? _19679.x : _19687.x, _23574.y ? _19679.y : _19687.y);
            }
            else
            {
                _22193 = _19234;
                _19912 = _5325;
                _19831 = false;
                _19689 = _7816;
            }
            _22192 = _22193;
            _19911 = _19912;
            _19830 = _19831;
            _19688 = _19689;
        }
        else
        {
            _22192 = 0.0f.xxx;
            _19911 = _5325;
            _19830 = false;
            _19688 = _7816;
        }
        float2 _19690;
        if (_7838)
        {
            float2 _8263 = clamp((((_19667 + (_19688 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8266 = tan(_8263.x);
            _19690 = (float2(_8266 / cbFI_DeviceToViewDepth.z, (tan(_8263.y) * sqrt(1.0f + (_8266 * _8266))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19690 = _19667 + (_19688 * cbFI_Timestep);
        }
        float _5529 = cbFI_Timestep - 1.0f;
        float2 _19692;
        if (_7838)
        {
            float2 _8334 = clamp((((_19667 + (_19688 * _5529)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8337 = tan(_8334.x);
            _19692 = (float2(_8337 / cbFI_DeviceToViewDepth.z, (tan(_8334.y) * sqrt(1.0f + (_8337 * _8337))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19692 = _19667 + (_19688 * _5529);
        }
        float _5534 = -cbFI_Timestep;
        float2 _19693;
        if (_7838)
        {
            float2 _8405 = clamp((((_19667 + (_7810 * _5534)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8408 = tan(_8405.x);
            _19693 = (float2(_8408 / cbFI_DeviceToViewDepth.z, (tan(_8405.y) * sqrt(1.0f + (_8408 * _8408))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19693 = _19667 + (_7810 * _5534);
        }
        float _5539 = 1.0f - cbFI_Timestep;
        float2 _19694;
        if (_7838)
        {
            float2 _8476 = clamp((((_19667 + (_7810 * _5539)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8479 = tan(_8476.x);
            _19694 = (float2(_8479 / cbFI_DeviceToViewDepth.z, (tan(_8476.y) * sqrt(1.0f + (_8479 * _8479))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19694 = _19667 + (_7810 * _5539);
        }
        float4 _8514 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19690, 0.0f);
        float3 _8515 = _8514.xyz;
        float4 _8522 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19692, 0.0f);
        float3 _8523 = _8522.xyz;
        float4 _8530 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19693, 0.0f);
        float3 _8531 = _8530.xyz;
        float4 _8538 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19694, 0.0f);
        float3 _8539 = _8538.xyz;
        float4 _8553 = exp(_7804 - max(max(max(_7804.x, _7804.y), _7804.z), _7804.w).xxxx);
        float4 _8560 = _8553 / (dot(_8553, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5555 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19901;
        float _21209;
        if (_5555)
        {
            float2 _5561 = 0.5f.xx / _5316;
            float _5564 = _5561.x;
            float _5565 = -_5564;
            float _5567 = _5561.y;
            float _5568 = -_5567;
            float2 _5570 = _5314 + float2(_5565, _5568);
            float2 _5572 = float2(cbFI_DisplaySize);
            bool _19711;
            do
            {
                bool _8640 = all(bool2(_5570.x > 0.0f.xx.x, _5570.y > 0.0f.xx.y));
                bool _8646;
                if (_8640)
                {
                    _8646 = all(bool2(_5570.x < 1.0f.xx.x, _5570.y < 1.0f.xx.y));
                }
                else
                {
                    _8646 = _8640;
                }
                if (!_8646)
                {
                    _19711 = false;
                    break;
                }
                uint _8653_dummy_parameter;
                float4x4 _19709;
                do
                {
                    float4x4 _8667;
                    bool _19708;
                    do
                    {
                        _8667 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19708 = false;
                            break;
                        }
                        uint _8701 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8701 + 32u) * 4 + 0) != 1u)
                        {
                            _19708 = false;
                            break;
                        }
                        uint _19705;
                        _19705 = 0u;
                        for (; _19705 < 4u; _19705++)
                        {
                            for (uint _19706 = 0u; _19706 < 4u; )
                            {
                                _8667[_19705][_19706] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8701 + (_19705 * 4u)) + _19706) * 4 + 0));
                                _19706++;
                                continue;
                            }
                        }
                        _19708 = true;
                        break;
                    } while(false);
                    if (_19708)
                    {
                        _19709 = _8667;
                        break;
                    }
                    _19709 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19710;
                do
                {
                    float _8778 = _5570.x;
                    float _8781 = 1.0f - _5570.y;
                    float4 _8792 = mul(float4((float2(_8778, _8781) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5570 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8653_dummy_parameter))))), 0)).x, 1.0f), _19709);
                    float _8794 = _8792.w;
                    if (!(_8794 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19710 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8807 = ((_8792.xy / _8794.xx) + 1.0f.xx) * 0.5f;
                    _19710 = float2(_8807.x - _8778, _8781 - _8807.y);
                    break;
                } while(false);
                float2 _8604 = abs(_19710);
                if (any(bool2(_8604.x > 100000.0f.xx.x, _8604.y > 100000.0f.xx.y)))
                {
                    _19711 = false;
                    break;
                }
                float _8612 = length(_19710 * _5572);
                uint _8827_dummy_parameter;
                bool _8626 = _8612 > ((8.0f * _5572.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8633;
                if (_8626)
                {
                    _8633 = length((r_motion_tp1.Load(int3(int2(floor(_5570 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8827_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5572) < (0.20000000298023223876953125f * _8612);
                }
                else
                {
                    _8633 = _8626;
                }
                _19711 = _8633;
                break;
            } while(false);
            float2 _5582 = _5314 + float2(_5564, _5568);
            bool _19718;
            do
            {
                bool _8913 = all(bool2(_5582.x > 0.0f.xx.x, _5582.y > 0.0f.xx.y));
                bool _8919;
                if (_8913)
                {
                    _8919 = all(bool2(_5582.x < 1.0f.xx.x, _5582.y < 1.0f.xx.y));
                }
                else
                {
                    _8919 = _8913;
                }
                if (!_8919)
                {
                    _19718 = false;
                    break;
                }
                uint _8926_dummy_parameter;
                float4x4 _19716;
                do
                {
                    float4x4 _8940;
                    bool _19715;
                    do
                    {
                        _8940 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19715 = false;
                            break;
                        }
                        uint _8974 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8974 + 32u) * 4 + 0) != 1u)
                        {
                            _19715 = false;
                            break;
                        }
                        uint _19712;
                        _19712 = 0u;
                        for (; _19712 < 4u; _19712++)
                        {
                            for (uint _19713 = 0u; _19713 < 4u; )
                            {
                                _8940[_19712][_19713] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8974 + (_19712 * 4u)) + _19713) * 4 + 0));
                                _19713++;
                                continue;
                            }
                        }
                        _19715 = true;
                        break;
                    } while(false);
                    if (_19715)
                    {
                        _19716 = _8940;
                        break;
                    }
                    _19716 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19717;
                do
                {
                    float _9051 = _5582.x;
                    float _9054 = 1.0f - _5582.y;
                    float4 _9065 = mul(float4((float2(_9051, _9054) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5582 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8926_dummy_parameter))))), 0)).x, 1.0f), _19716);
                    float _9067 = _9065.w;
                    if (!(_9067 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19717 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9080 = ((_9065.xy / _9067.xx) + 1.0f.xx) * 0.5f;
                    _19717 = float2(_9080.x - _9051, _9054 - _9080.y);
                    break;
                } while(false);
                float2 _8877 = abs(_19717);
                if (any(bool2(_8877.x > 100000.0f.xx.x, _8877.y > 100000.0f.xx.y)))
                {
                    _19718 = false;
                    break;
                }
                float _8885 = length(_19717 * _5572);
                uint _9100_dummy_parameter;
                bool _8899 = _8885 > ((8.0f * _5572.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8906;
                if (_8899)
                {
                    _8906 = length((r_motion_tp1.Load(int3(int2(floor(_5582 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9100_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5572) < (0.20000000298023223876953125f * _8885);
                }
                else
                {
                    _8906 = _8899;
                }
                _19718 = _8906;
                break;
            } while(false);
            float2 _5595 = _5314 + float2(_5565, _5567);
            bool _19725;
            do
            {
                bool _9186 = all(bool2(_5595.x > 0.0f.xx.x, _5595.y > 0.0f.xx.y));
                bool _9192;
                if (_9186)
                {
                    _9192 = all(bool2(_5595.x < 1.0f.xx.x, _5595.y < 1.0f.xx.y));
                }
                else
                {
                    _9192 = _9186;
                }
                if (!_9192)
                {
                    _19725 = false;
                    break;
                }
                uint _9199_dummy_parameter;
                float4x4 _19723;
                do
                {
                    float4x4 _9213;
                    bool _19722;
                    do
                    {
                        _9213 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19722 = false;
                            break;
                        }
                        uint _9247 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9247 + 32u) * 4 + 0) != 1u)
                        {
                            _19722 = false;
                            break;
                        }
                        uint _19719;
                        _19719 = 0u;
                        for (; _19719 < 4u; _19719++)
                        {
                            for (uint _19720 = 0u; _19720 < 4u; )
                            {
                                _9213[_19719][_19720] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9247 + (_19719 * 4u)) + _19720) * 4 + 0));
                                _19720++;
                                continue;
                            }
                        }
                        _19722 = true;
                        break;
                    } while(false);
                    if (_19722)
                    {
                        _19723 = _9213;
                        break;
                    }
                    _19723 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19724;
                do
                {
                    float _9324 = _5595.x;
                    float _9327 = 1.0f - _5595.y;
                    float4 _9338 = mul(float4((float2(_9324, _9327) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5595 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9199_dummy_parameter))))), 0)).x, 1.0f), _19723);
                    float _9340 = _9338.w;
                    if (!(_9340 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19724 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9353 = ((_9338.xy / _9340.xx) + 1.0f.xx) * 0.5f;
                    _19724 = float2(_9353.x - _9324, _9327 - _9353.y);
                    break;
                } while(false);
                float2 _9150 = abs(_19724);
                if (any(bool2(_9150.x > 100000.0f.xx.x, _9150.y > 100000.0f.xx.y)))
                {
                    _19725 = false;
                    break;
                }
                float _9158 = length(_19724 * _5572);
                uint _9373_dummy_parameter;
                bool _9172 = _9158 > ((8.0f * _5572.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9179;
                if (_9172)
                {
                    _9179 = length((r_motion_tp1.Load(int3(int2(floor(_5595 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9373_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5572) < (0.20000000298023223876953125f * _9158);
                }
                else
                {
                    _9179 = _9172;
                }
                _19725 = _9179;
                break;
            } while(false);
            float2 _5607 = _5314 + _5561;
            bool _19732;
            do
            {
                bool _9459 = all(bool2(_5607.x > 0.0f.xx.x, _5607.y > 0.0f.xx.y));
                bool _9465;
                if (_9459)
                {
                    _9465 = all(bool2(_5607.x < 1.0f.xx.x, _5607.y < 1.0f.xx.y));
                }
                else
                {
                    _9465 = _9459;
                }
                if (!_9465)
                {
                    _19732 = false;
                    break;
                }
                uint _9472_dummy_parameter;
                float4x4 _19730;
                do
                {
                    float4x4 _9486;
                    bool _19729;
                    do
                    {
                        _9486 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19729 = false;
                            break;
                        }
                        uint _9520 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9520 + 32u) * 4 + 0) != 1u)
                        {
                            _19729 = false;
                            break;
                        }
                        uint _19726;
                        _19726 = 0u;
                        for (; _19726 < 4u; _19726++)
                        {
                            for (uint _19727 = 0u; _19727 < 4u; )
                            {
                                _9486[_19726][_19727] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9520 + (_19726 * 4u)) + _19727) * 4 + 0));
                                _19727++;
                                continue;
                            }
                        }
                        _19729 = true;
                        break;
                    } while(false);
                    if (_19729)
                    {
                        _19730 = _9486;
                        break;
                    }
                    _19730 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19731;
                do
                {
                    float _9597 = _5607.x;
                    float _9600 = 1.0f - _5607.y;
                    float4 _9611 = mul(float4((float2(_9597, _9600) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5607 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9472_dummy_parameter))))), 0)).x, 1.0f), _19730);
                    float _9613 = _9611.w;
                    if (!(_9613 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19731 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9626 = ((_9611.xy / _9613.xx) + 1.0f.xx) * 0.5f;
                    _19731 = float2(_9626.x - _9597, _9600 - _9626.y);
                    break;
                } while(false);
                float2 _9423 = abs(_19731);
                if (any(bool2(_9423.x > 100000.0f.xx.x, _9423.y > 100000.0f.xx.y)))
                {
                    _19732 = false;
                    break;
                }
                float _9431 = length(_19731 * _5572);
                uint _9646_dummy_parameter;
                bool _9445 = _9431 > ((8.0f * _5572.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9452;
                if (_9445)
                {
                    _9452 = length((r_motion_tp1.Load(int3(int2(floor(_5607 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9646_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5572) < (0.20000000298023223876953125f * _9431);
                }
                else
                {
                    _9452 = _9445;
                }
                _19732 = _9452;
                break;
            } while(false);
            float _5613 = 0.25f * (((float(_19711) + float(_19718)) + float(_19725)) + float(_19732));
            float4 _19902;
            if (_5613 < 1.0f)
            {
                bool _19739;
                do
                {
                    bool _9732 = all(bool2(_19690.x > 0.0f.xx.x, _19690.y > 0.0f.xx.y));
                    bool _9738;
                    if (_9732)
                    {
                        _9738 = all(bool2(_19690.x < 1.0f.xx.x, _19690.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9738 = _9732;
                    }
                    if (!_9738)
                    {
                        _19739 = false;
                        break;
                    }
                    uint _9745_dummy_parameter;
                    float4x4 _19737;
                    do
                    {
                        float4x4 _9759;
                        bool _19736;
                        do
                        {
                            _9759 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19736 = false;
                                break;
                            }
                            uint _9793 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9793 + 32u) * 4 + 0) != 1u)
                            {
                                _19736 = false;
                                break;
                            }
                            uint _19733;
                            _19733 = 0u;
                            for (; _19733 < 4u; _19733++)
                            {
                                for (uint _19734 = 0u; _19734 < 4u; )
                                {
                                    _9759[_19733][_19734] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9793 + (_19733 * 4u)) + _19734) * 4 + 0));
                                    _19734++;
                                    continue;
                                }
                            }
                            _19736 = true;
                            break;
                        } while(false);
                        if (_19736)
                        {
                            _19737 = _9759;
                            break;
                        }
                        _19737 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19738;
                    do
                    {
                        float _9873 = 1.0f - _19690.y;
                        float4 _9884 = mul(float4((float2(_19690.x, _9873) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19690 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9745_dummy_parameter))))), 0)).x, 1.0f), _19737);
                        float _9886 = _9884.w;
                        if (!(_9886 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19738 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9899 = ((_9884.xy / _9886.xx) + 1.0f.xx) * 0.5f;
                        _19738 = float2(_9899.x - _19690.x, _9873 - _9899.y);
                        break;
                    } while(false);
                    float2 _9696 = abs(_19738);
                    if (any(bool2(_9696.x > 100000.0f.xx.x, _9696.y > 100000.0f.xx.y)))
                    {
                        _19739 = false;
                        break;
                    }
                    float _9704 = length(_19738 * _5572);
                    uint _9919_dummy_parameter;
                    bool _9718 = _9704 > ((8.0f * _5572.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9725;
                    if (_9718)
                    {
                        _9725 = length((r_motion_tp1.Load(int3(int2(floor(_19690 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9919_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5572) < (0.20000000298023223876953125f * _9704);
                    }
                    else
                    {
                        _9725 = _9718;
                    }
                    _19739 = _9725;
                    break;
                } while(false);
                bool _19746;
                do
                {
                    bool _10005 = all(bool2(_19692.x > 0.0f.xx.x, _19692.y > 0.0f.xx.y));
                    bool _10011;
                    if (_10005)
                    {
                        _10011 = all(bool2(_19692.x < 1.0f.xx.x, _19692.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10011 = _10005;
                    }
                    if (!_10011)
                    {
                        _19746 = false;
                        break;
                    }
                    uint _10018_dummy_parameter;
                    float4x4 _19744;
                    do
                    {
                        float4x4 _10032;
                        bool _19743;
                        do
                        {
                            _10032 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19743 = false;
                                break;
                            }
                            uint _10066 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10066 + 32u) * 4 + 0) != 1u)
                            {
                                _19743 = false;
                                break;
                            }
                            uint _19740;
                            _19740 = 0u;
                            for (; _19740 < 4u; _19740++)
                            {
                                for (uint _19741 = 0u; _19741 < 4u; )
                                {
                                    _10032[_19740][_19741] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10066 + (_19740 * 4u)) + _19741) * 4 + 0));
                                    _19741++;
                                    continue;
                                }
                            }
                            _19743 = true;
                            break;
                        } while(false);
                        if (_19743)
                        {
                            _19744 = _10032;
                            break;
                        }
                        _19744 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19745;
                    do
                    {
                        float _10146 = 1.0f - _19692.y;
                        float4 _10157 = mul(float4((float2(_19692.x, _10146) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19692 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10018_dummy_parameter))))), 0)).x, 1.0f), _19744);
                        float _10159 = _10157.w;
                        if (!(_10159 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19745 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10172 = ((_10157.xy / _10159.xx) + 1.0f.xx) * 0.5f;
                        _19745 = float2(_10172.x - _19692.x, _10146 - _10172.y);
                        break;
                    } while(false);
                    float2 _9969 = abs(_19745);
                    if (any(bool2(_9969.x > 100000.0f.xx.x, _9969.y > 100000.0f.xx.y)))
                    {
                        _19746 = false;
                        break;
                    }
                    float _9977 = length(_19745 * _5572);
                    uint _10192_dummy_parameter;
                    bool _9991 = _9977 > ((8.0f * _5572.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9998;
                    if (_9991)
                    {
                        _9998 = length((r_motion_tp1.Load(int3(int2(floor(_19692 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10192_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5572) < (0.20000000298023223876953125f * _9977);
                    }
                    else
                    {
                        _9998 = _9991;
                    }
                    _19746 = _9998;
                    break;
                } while(false);
                bool _19753;
                do
                {
                    bool _10278 = all(bool2(_19693.x > 0.0f.xx.x, _19693.y > 0.0f.xx.y));
                    bool _10284;
                    if (_10278)
                    {
                        _10284 = all(bool2(_19693.x < 1.0f.xx.x, _19693.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10284 = _10278;
                    }
                    if (!_10284)
                    {
                        _19753 = false;
                        break;
                    }
                    uint _10291_dummy_parameter;
                    float4x4 _19751;
                    do
                    {
                        float4x4 _10305;
                        bool _19750;
                        do
                        {
                            _10305 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19750 = false;
                                break;
                            }
                            uint _10339 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10339 + 32u) * 4 + 0) != 1u)
                            {
                                _19750 = false;
                                break;
                            }
                            uint _19747;
                            _19747 = 0u;
                            for (; _19747 < 4u; _19747++)
                            {
                                for (uint _19748 = 0u; _19748 < 4u; )
                                {
                                    _10305[_19747][_19748] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10339 + (_19747 * 4u)) + _19748) * 4 + 0));
                                    _19748++;
                                    continue;
                                }
                            }
                            _19750 = true;
                            break;
                        } while(false);
                        if (_19750)
                        {
                            _19751 = _10305;
                            break;
                        }
                        _19751 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19752;
                    do
                    {
                        float _10419 = 1.0f - _19693.y;
                        float4 _10430 = mul(float4((float2(_19693.x, _10419) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19693 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10291_dummy_parameter))))), 0)).x, 1.0f), _19751);
                        float _10432 = _10430.w;
                        if (!(_10432 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19752 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10445 = ((_10430.xy / _10432.xx) + 1.0f.xx) * 0.5f;
                        _19752 = float2(_10445.x - _19693.x, _10419 - _10445.y);
                        break;
                    } while(false);
                    float2 _10242 = abs(_19752);
                    if (any(bool2(_10242.x > 100000.0f.xx.x, _10242.y > 100000.0f.xx.y)))
                    {
                        _19753 = false;
                        break;
                    }
                    float _10250 = length(_19752 * _5572);
                    uint _10465_dummy_parameter;
                    bool _10264 = _10250 > ((8.0f * _5572.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10271;
                    if (_10264)
                    {
                        _10271 = length((r_motion_tp1.Load(int3(int2(floor(_19693 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10465_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5572) < (0.20000000298023223876953125f * _10250);
                    }
                    else
                    {
                        _10271 = _10264;
                    }
                    _19753 = _10271;
                    break;
                } while(false);
                bool _19760;
                do
                {
                    bool _10551 = all(bool2(_19694.x > 0.0f.xx.x, _19694.y > 0.0f.xx.y));
                    bool _10557;
                    if (_10551)
                    {
                        _10557 = all(bool2(_19694.x < 1.0f.xx.x, _19694.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10557 = _10551;
                    }
                    if (!_10557)
                    {
                        _19760 = false;
                        break;
                    }
                    uint _10564_dummy_parameter;
                    float4x4 _19758;
                    do
                    {
                        float4x4 _10578;
                        bool _19757;
                        do
                        {
                            _10578 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19757 = false;
                                break;
                            }
                            uint _10612 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10612 + 32u) * 4 + 0) != 1u)
                            {
                                _19757 = false;
                                break;
                            }
                            uint _19754;
                            _19754 = 0u;
                            for (; _19754 < 4u; _19754++)
                            {
                                for (uint _19755 = 0u; _19755 < 4u; )
                                {
                                    _10578[_19754][_19755] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10612 + (_19754 * 4u)) + _19755) * 4 + 0));
                                    _19755++;
                                    continue;
                                }
                            }
                            _19757 = true;
                            break;
                        } while(false);
                        if (_19757)
                        {
                            _19758 = _10578;
                            break;
                        }
                        _19758 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19759;
                    do
                    {
                        float _10692 = 1.0f - _19694.y;
                        float4 _10703 = mul(float4((float2(_19694.x, _10692) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19694 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10564_dummy_parameter))))), 0)).x, 1.0f), _19758);
                        float _10705 = _10703.w;
                        if (!(_10705 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19759 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10718 = ((_10703.xy / _10705.xx) + 1.0f.xx) * 0.5f;
                        _19759 = float2(_10718.x - _19694.x, _10692 - _10718.y);
                        break;
                    } while(false);
                    float2 _10515 = abs(_19759);
                    if (any(bool2(_10515.x > 100000.0f.xx.x, _10515.y > 100000.0f.xx.y)))
                    {
                        _19760 = false;
                        break;
                    }
                    float _10523 = length(_19759 * _5572);
                    uint _10738_dummy_parameter;
                    bool _10537 = _10523 > ((8.0f * _5572.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10544;
                    if (_10537)
                    {
                        _10544 = length((r_motion_tp1.Load(int3(int2(floor(_19694 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10738_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5572) < (0.20000000298023223876953125f * _10523);
                    }
                    else
                    {
                        _10544 = _10537;
                    }
                    _19760 = _10544;
                    break;
                } while(false);
                float4 _5640 = _8560 * float4(_19739 ? 0.0f : 1.0f, _19746 ? 0.0f : 1.0f, _19753 ? 0.0f : 1.0f, _19760 ? 0.0f : 1.0f);
                float _5642 = dot(_5640, 1.0f.xxxx);
                float4 _19903;
                if (_5642 > 0.001000000047497451305389404296875f)
                {
                    _19903 = _5640 / _5642.xxxx;
                }
                else
                {
                    _19903 = _8560;
                }
                _19902 = _19903;
            }
            else
            {
                _19902 = _8560;
            }
            _21209 = _5613;
            _19901 = _19902;
        }
        else
        {
            _21209 = 0.0f;
            _19901 = _8560;
        }
        bool _5659 = _5351 && (!_19830);
        bool _5668;
        if (_5659)
        {
            _5668 = (_19901.z + _19901.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5668 = _5659;
        }
        bool _5679;
        if (_5668)
        {
            _5679 = length((_19693 - _19690) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5679 = _5668;
        }
        bool _19990;
        if (_5679)
        {
            uint4 _10767 = r_warped_motion_qdata_tp1.Load(int3(_19911, 0));
            uint _10768 = _10767.x;
            bool _19993;
            if (_10768 != 0u)
            {
                float _19979;
                if (_10768 == 0u)
                {
                    _19979 = -1.0f;
                }
                else
                {
                    _19979 = float((_10768 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5689 = _19979 - 0.12000000476837158203125f;
                bool _10787 = all(bool2(_19693.x > 0.0f.xx.x, _19693.y > 0.0f.xx.y));
                bool _10793;
                if (_10787)
                {
                    _10793 = all(bool2(_19693.x < 1.0f.xx.x, _19693.y < 1.0f.xx.y));
                }
                else
                {
                    _10793 = _10787;
                }
                bool _5699;
                if (_10793)
                {
                    uint _10800_dummy_parameter;
                    _5699 = (log(((r_depth_tm1.Load(int3(int2(floor(_19693 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10800_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5689;
                }
                else
                {
                    _5699 = _10793;
                }
                bool _5713;
                if (!_5699)
                {
                    bool _10830 = all(bool2(_19694.x > 0.0f.xx.x, _19694.y > 0.0f.xx.y));
                    bool _10836;
                    if (_10830)
                    {
                        _10836 = all(bool2(_19694.x < 1.0f.xx.x, _19694.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10836 = _10830;
                    }
                    bool _5711;
                    if (_10836)
                    {
                        uint _10843_dummy_parameter;
                        _5711 = (log(((r_depth_tp1.Load(int3(int2(floor(_19694 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10843_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5689;
                    }
                    else
                    {
                        _5711 = _10836;
                    }
                    _5713 = _5711;
                }
                else
                {
                    _5713 = _5699;
                }
                _19993 = _5713;
            }
            else
            {
                _19993 = false;
            }
            _19990 = _19993;
        }
        else
        {
            _19990 = false;
        }
        bool _5718 = _19830 || _19990;
        bool _5723;
        if (_5718)
        {
            bool _10873 = all(bool2(_19690.x > 0.0f.xx.x, _19690.y > 0.0f.xx.y));
            bool _10879;
            if (_10873)
            {
                _10879 = all(bool2(_19690.x < 1.0f.xx.x, _19690.y < 1.0f.xx.y));
            }
            else
            {
                _10879 = _10873;
            }
            _5723 = _10879;
        }
        else
        {
            _5723 = _5718;
        }
        bool _5728;
        if (_5723)
        {
            bool _10884 = all(bool2(_19692.x > 0.0f.xx.x, _19692.y > 0.0f.xx.y));
            bool _10890;
            if (_10884)
            {
                _10890 = all(bool2(_19692.x < 1.0f.xx.x, _19692.y < 1.0f.xx.y));
            }
            else
            {
                _10890 = _10884;
            }
            _5728 = _10890;
        }
        else
        {
            _5728 = _5723;
        }
        float4 _20113;
        if (_5728)
        {
            float _5734 = _19901.x + _19901.y;
            float _5739 = _19901.z + _19901.w;
            float _20008;
            if (_5734 > 0.001000000047497451305389404296875f)
            {
                _20008 = _19901.x / _5734;
            }
            else
            {
                _20008 = _5539;
            }
            _20113 = float4(_19901.x + (_5739 * _20008), _19901.y + (_5739 * (1.0f - _20008)), 0.0f, 0.0f);
        }
        else
        {
            _20113 = _19901;
        }
        bool _10918 = (cbFI_pad0 & 1024u) != 0u;
        bool _10894 = !_10918;
        bool _10895 = !_10894;
        bool _10912;
        if (_10895)
        {
            _10912 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19911.y * cbFI_MvDepthLaneSize.x) + _19911.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _10912 = _10894;
        }
        bool _10944;
        if (_10895)
        {
            _10944 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5330.y * cbFI_FlowLaneSize.x) + _5330.x)) * 4 + 0) != 0u;
        }
        else
        {
            _10944 = _10894;
        }
        float _5774 = float(_10944);
        bool _20134;
        float4 _20173;
        float3 _21927;
        if (_10918)
        {
            bool _5784;
            if (_10912)
            {
                _5784 = all(bool2(_19690.x > 0.0f.xx.x, _19690.y > 0.0f.xx.y));
            }
            else
            {
                _5784 = _10912;
            }
            bool _5790;
            if (_5784)
            {
                _5790 = all(bool2(_19690.x < 1.0f.xx.x, _19690.y < 1.0f.xx.y));
            }
            else
            {
                _5790 = _5784;
            }
            bool _5797;
            if (_10912)
            {
                _5797 = all(bool2(_19692.x > 0.0f.xx.x, _19692.y > 0.0f.xx.y));
            }
            else
            {
                _5797 = _10912;
            }
            bool _5803;
            if (_5797)
            {
                _5803 = all(bool2(_19692.x < 1.0f.xx.x, _19692.y < 1.0f.xx.y));
            }
            else
            {
                _5803 = _5797;
            }
            bool _5810;
            if (_10944)
            {
                _5810 = all(bool2(_19693.x > 0.0f.xx.x, _19693.y > 0.0f.xx.y));
            }
            else
            {
                _5810 = _10944;
            }
            bool _5816;
            if (_5810)
            {
                _5816 = all(bool2(_19693.x < 1.0f.xx.x, _19693.y < 1.0f.xx.y));
            }
            else
            {
                _5816 = _5810;
            }
            bool _5823;
            if (_10944)
            {
                _5823 = all(bool2(_19694.x > 0.0f.xx.x, _19694.y > 0.0f.xx.y));
            }
            else
            {
                _5823 = _10944;
            }
            bool _5829;
            if (_5823)
            {
                _5829 = all(bool2(_19694.x < 1.0f.xx.x, _19694.y < 1.0f.xx.y));
            }
            else
            {
                _5829 = _5823;
            }
            bool _5831 = !_10912;
            if (_5831)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10986;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _10986);
                }
            }
            bool _5836 = !_10944;
            if (_5836)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10996;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _10996);
                }
            }
            if (_10912 && _5836)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11006;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11006);
                }
            }
            if (_5831 && _10944)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11016;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11016);
                }
            }
            float _5855 = float(_5790);
            float _5857 = float(_5803);
            bool _5860 = _5816 && _5829;
            float _20042;
            if (_5860)
            {
                _20042 = 1.0f;
            }
            else
            {
                _20042 = (_5816 || _5829) ? 0.5f : 0.0f;
            }
            bool _20057;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5790)) && (!_5803))
            {
                bool _5890;
                if (_5860)
                {
                    float _20050;
                    do
                    {
                        bool _11100 = all(bool2(_19693.x > 0.0f.xx.x, _19693.y > 0.0f.xx.y));
                        bool _11106;
                        if (_11100)
                        {
                            _11106 = all(bool2(_19693.x < 1.0f.xx.x, _19693.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11106 = _11100;
                        }
                        bool _11037 = !_11106;
                        bool _11044;
                        if (!_11037)
                        {
                            bool _11111 = all(bool2(_19694.x > 0.0f.xx.x, _19694.y > 0.0f.xx.y));
                            bool _11117;
                            if (_11111)
                            {
                                _11117 = all(bool2(_19694.x < 1.0f.xx.x, _19694.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11117 = _11111;
                            }
                            _11044 = !_11117;
                        }
                        else
                        {
                            _11044 = _11037;
                        }
                        if (_11044)
                        {
                            _20050 = 0.0f;
                            break;
                        }
                        uint _11124_dummy_parameter;
                        uint _11140_dummy_parameter;
                        float4x4 _20049;
                        do
                        {
                            float4x4 _11154;
                            bool _20048;
                            do
                            {
                                _11154 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20048 = false;
                                    break;
                                }
                                uint _11188 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11188 + 32u) * 4 + 0) != 1u)
                                {
                                    _20048 = false;
                                    break;
                                }
                                uint _20045;
                                _20045 = 0u;
                                for (; _20045 < 4u; _20045++)
                                {
                                    for (uint _20046 = 0u; _20046 < 4u; )
                                    {
                                        _11154[_20045][_20046] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11188 + 16u) + (_20045 * 4u)) + _20046) * 4 + 0));
                                        _20046++;
                                        continue;
                                    }
                                }
                                _20048 = true;
                                break;
                            } while(false);
                            if (_20048)
                            {
                                _20049 = _11154;
                                break;
                            }
                            _20049 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11065 = mul(float4((float2(_19693.x, 1.0f - _19693.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19693 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11124_dummy_parameter))))), 0)).x, 1.0f), _20049);
                        float _11067 = _11065.w;
                        if (abs(_11067) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20050 = 0.0f;
                            break;
                        }
                        float _11078 = abs(cbFI_DeviceToViewDepth.y / ((_11065.z / _11067) - cbFI_DeviceToViewDepth.x));
                        float _11081 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19694 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11140_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20050 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11078 - _11081) / max(max(_11078, _11081), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5890 = _20050 >= 0.5f;
                }
                else
                {
                    _5890 = _5860;
                }
                bool _5898;
                if (_5890)
                {
                    _5898 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5898 = _5890;
                }
                bool _20058;
                if (_5898)
                {
                    uint _11292_dummy_parameter;
                    float4x4 _20055;
                    do
                    {
                        float4x4 _11306;
                        bool _20054;
                        do
                        {
                            _11306 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20054 = false;
                                break;
                            }
                            uint _11340 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11340 + 32u) * 4 + 0) != 1u)
                            {
                                _20054 = false;
                                break;
                            }
                            uint _20051;
                            _20051 = 0u;
                            for (; _20051 < 4u; _20051++)
                            {
                                for (uint _20052 = 0u; _20052 < 4u; )
                                {
                                    _11306[_20051][_20052] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11340 + 16u) + (_20051 * 4u)) + _20052) * 4 + 0));
                                    _20052++;
                                    continue;
                                }
                            }
                            _20054 = true;
                            break;
                        } while(false);
                        if (_20054)
                        {
                            _20055 = _11306;
                            break;
                        }
                        _20055 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20056;
                    do
                    {
                        float _11420 = 1.0f - _19693.y;
                        float4 _11431 = mul(float4((float2(_19693.x, _11420) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19693 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11292_dummy_parameter))))), 0)).x, 1.0f), _20055);
                        float _11433 = _11431.w;
                        if (!(_11433 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20056 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11446 = ((_11431.xy / _11433.xx) + 1.0f.xx) * 0.5f;
                        _20056 = float2(_11446.x - _19693.x, _11420 - _11446.y);
                        break;
                    } while(false);
                    float2 _5911 = float2(cbFI_DisplaySize);
                    _20058 = length(((_19693 + _20056) - _19694) * _5911) <= ((0.100000001490116119384765625f * length(_20056 * _5911)) + 8.0f);
                }
                else
                {
                    _20058 = _5890;
                }
                _20057 = _20058;
            }
            else
            {
                _20057 = true;
            }
            bool _5925 = !_20057;
            bool _23578 = _5925 ? false : _5829;
            bool _23579 = _5925 ? false : _5816;
            bool _20135;
            float4 _20174;
            if (!(((_5790 && _5803) && _23579) && _23578))
            {
                float4 _5947 = _20113 * float4(_5855, _5857, float(_23579), float(_23578));
                float _5949 = dot(_5947, 1.0f.xxxx);
                bool _5952 = !(_5949 > 0.0f);
                float4 _20175;
                if (!_5952)
                {
                    _20175 = _5947 / _5949.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11468;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11468);
                    }
                    _20175 = 0.0f.xxxx;
                }
                _20174 = _20175;
                _20135 = _5952;
            }
            else
            {
                _20174 = _20113;
                _20135 = false;
            }
            _21927 = float3(_5855, _5857, _20042);
            _20173 = _20174;
            _20134 = _20135;
        }
        else
        {
            _21927 = float3(float(_10912), _5774, 0.0f);
            _20173 = _20113;
            _20134 = false;
        }
        bool _5970 = !_20134;
        float4 _20266;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5970)
        {
            float _5977 = _20173.x + _20173.y;
            float4 _20267;
            if (_5977 > 0.001000000047497451305389404296875f)
            {
                _20267 = float4(_20173.x / _5977, _20173.y / _5977, 0.0f, 0.0f);
            }
            else
            {
                _20267 = float4(_5539, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20266 = _20267;
        }
        else
        {
            _20266 = _20173;
        }
        float4 _20443;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5970) && _10912)
        {
            float _20240;
            do
            {
                uint4 _11608 = r_warped_motion_qdata_tp1.Load(int3(_19911, 0));
                uint _11609 = _11608.x;
                if (_11609 != 0u)
                {
                    float _20239;
                    if (_11609 == 0u)
                    {
                        _20239 = -1.0f;
                    }
                    else
                    {
                        _20239 = float((_11609 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20240 = _20239;
                    break;
                }
                int _20222;
                uint _20223;
                _20223 = _11609;
                _20222 = -1;
                uint _20238;
                for (; _20222 <= 1; _20223 = _20238, _20222++)
                {
                    _20238 = _20223;
                    for (int _20236 = -1; _20236 <= 1; )
                    {
                        _20238 = max(_20238, r_warped_motion_qdata_tp1.Load(int3(clamp(_19911 + int2(_20236, _20222), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20236++;
                        continue;
                    }
                }
                if (_20223 != 0u)
                {
                    float _20235;
                    if (_20223 == 0u)
                    {
                        _20235 = -1.0f;
                    }
                    else
                    {
                        _20235 = float((_20223 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20240 = _20235;
                    break;
                }
                uint _20225;
                _20225 = 4294967295u;
                uint _23211;
                for (int _20224 = 0; _20224 < 8; _20225 = _23211, _20224++)
                {
                    int _20228 = 0;
                    for (;;)
                    {
                        if (_20228 < 5)
                        {
                            int2 _11559 = _19911 + (_1239[_20224] * _1248[_20228].xx);
                            bool _11562 = any(bool2(_11559.x < int2(0, 0).x, _11559.y < int2(0, 0).y));
                            bool _11570;
                            if (!_11562)
                            {
                                _11570 = any(bool2(_11559.x >= cbFI_MvDepthLaneSize.x, _11559.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11570 = _11562;
                            }
                            if (_11570)
                            {
                                _23211 = _20225;
                                break;
                            }
                            uint4 _11648 = r_warped_motion_qdata_tp1.Load(int3(_11559, 0));
                            uint _11649 = _11648.x;
                            if (_11649 != 0u)
                            {
                                _23211 = min(_20225, _11649);
                                break;
                            }
                            _20228++;
                            continue;
                        }
                        else
                        {
                            _23211 = _20225;
                            break;
                        }
                    }
                }
                float _20227;
                if (_20225 == 4294967295u)
                {
                    _20227 = -1.0f;
                }
                else
                {
                    float _20226;
                    if (_20225 == 0u)
                    {
                        _20226 = -1.0f;
                    }
                    else
                    {
                        _20226 = float((_20225 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20227 = _20226;
                }
                _20240 = _20227;
                break;
            } while(false);
            float _6013 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6016 = r_warped_motion_qdata_tp1.Load(int3(_19911, 0)).x == 0u;
            bool _6022;
            if (_6016)
            {
                bool _11674 = all(bool2(_19690.x > 0.0f.xx.x, _19690.y > 0.0f.xx.y));
                bool _11680;
                if (_11674)
                {
                    _11680 = all(bool2(_19690.x < 1.0f.xx.x, _19690.y < 1.0f.xx.y));
                }
                else
                {
                    _11680 = _11674;
                }
                _6022 = _11680;
            }
            else
            {
                _6022 = _6016;
            }
            bool _6027;
            if (_6022)
            {
                bool _11685 = all(bool2(_19692.x > 0.0f.xx.x, _19692.y > 0.0f.xx.y));
                bool _11691;
                if (_11685)
                {
                    _11691 = all(bool2(_19692.x < 1.0f.xx.x, _19692.y < 1.0f.xx.y));
                }
                else
                {
                    _11691 = _11685;
                }
                _6027 = _11691;
            }
            else
            {
                _6027 = _6022;
            }
            bool _20252;
            float4 _20261;
            if (_6027)
            {
                uint _11698_dummy_parameter;
                float _11722 = log(((r_depth_tm1.Load(int3(int2(floor(_19690 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11698_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _11730_dummy_parameter;
                float _11754 = log(((r_depth_tp1.Load(int3(int2(floor(_19692 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11730_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _6038 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6045;
                if (_6038)
                {
                    _6045 = _11754 > (_11722 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6045 = _6038;
                }
                bool _20257;
                float4 _20279;
                if (_6045)
                {
                    _20279 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20257 = true;
                }
                else
                {
                    bool _6051 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6058;
                    if (_6051)
                    {
                        _6058 = _11722 > (_11754 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6058 = _6051;
                    }
                    bool4 _23580 = _6058.xxxx;
                    _20279 = float4(_23580.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20266.x, _23580.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20266.y, _23580.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20266.z, _23580.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20266.w);
                    _20257 = _6058 ? true : false;
                }
                _20261 = _20279;
                _20252 = _20257;
            }
            else
            {
                _20261 = _20266;
                _20252 = false;
            }
            float4 _20334;
            if (_20252)
            {
                _20334 = 1.0f.xxxx;
            }
            else
            {
                bool _6069 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6075;
                if (_6069)
                {
                    _6075 = _20261.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6075 = _6069;
                }
                bool _6080;
                if (_6075)
                {
                    bool _11760 = all(bool2(_19692.x > 0.0f.xx.x, _19692.y > 0.0f.xx.y));
                    bool _11766;
                    if (_11760)
                    {
                        _11766 = all(bool2(_19692.x < 1.0f.xx.x, _19692.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11766 = _11760;
                    }
                    _6080 = _11766;
                }
                else
                {
                    _6080 = _6075;
                }
                float4 _20335;
                if (_6080)
                {
                    float _20288;
                    if (_20240 >= 0.0f)
                    {
                        _20288 = _20240 - _6013;
                    }
                    else
                    {
                        float _20284;
                        _20284 = 2.0f;
                        float _11823;
                        for (int _20283 = 0; _20283 < 24; _20284 = _11823, _20283++)
                        {
                            float _11787 = float(_20283 & 7) * 0.785398185253143310546875f;
                            int _11789 = _20283 >> 3;
                            int _20285;
                            if (_11789 == 0)
                            {
                                _20285 = 16;
                            }
                            else
                            {
                                _20285 = (_11789 == 1) ? 48 : 96;
                            }
                            uint _11855_dummy_parameter;
                            _11823 = min(_20284, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19692 + ((cbFI_MvDepthLaneSizeRcp * float(_20285)) * float2(cos(_11787), sin(_11787))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11855_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20288 = _20284;
                    }
                    uint _11887_dummy_parameter;
                    float4 _20336;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_19692 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11887_dummy_parameter))))), 0)).x) > ((exp((_20288 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20336 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20336 = 1.0f.xxxx;
                    }
                    _20335 = _20336;
                }
                else
                {
                    _20335 = 1.0f.xxxx;
                }
                _20334 = _20335;
            }
            bool _6108 = _20240 >= 0.0f;
            bool _6109 = (!_20252) && _6108;
            bool _6116;
            if (_6109)
            {
                _6116 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6116 = _6109;
            }
            bool _6122;
            if (_6116)
            {
                _6122 = _20261.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6122 = _6116;
            }
            bool _6127;
            if (_6122)
            {
                bool _11912 = all(bool2(_19690.x > 0.0f.xx.x, _19690.y > 0.0f.xx.y));
                bool _11918;
                if (_11912)
                {
                    _11918 = all(bool2(_19690.x < 1.0f.xx.x, _19690.y < 1.0f.xx.y));
                }
                else
                {
                    _11918 = _11912;
                }
                _6127 = _11918;
            }
            else
            {
                _6127 = _6122;
            }
            float4 _20359;
            if (_6127)
            {
                float _20328;
                if (_6108)
                {
                    _20328 = _20240 - _6013;
                }
                else
                {
                    float _20324;
                    _20324 = 2.0f;
                    float _11975;
                    for (int _20323 = 0; _20323 < 24; _20324 = _11975, _20323++)
                    {
                        float _11939 = float(_20323 & 7) * 0.785398185253143310546875f;
                        int _11941 = _20323 >> 3;
                        int _20325;
                        if (_11941 == 0)
                        {
                            _20325 = 16;
                        }
                        else
                        {
                            _20325 = (_11941 == 1) ? 48 : 96;
                        }
                        uint _11991_dummy_parameter;
                        _11975 = min(_20324, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19690 + ((cbFI_MvDepthLaneSizeRcp * float(_20325)) * float2(cos(_11939), sin(_11939))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11991_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20328 = _20324;
                }
                uint _12039_dummy_parameter;
                float4 _20360;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_19690 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12039_dummy_parameter))))), 0)).x) > ((exp((_20328 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19386 = _20334;
                    _19386.x = 0.0f;
                    _20360 = _19386;
                }
                else
                {
                    _20360 = _20334;
                }
                _20359 = _20360;
            }
            else
            {
                _20359 = _20334;
            }
            float4 _20372;
            if (_6109)
            {
                float _12066 = (exp(((_20240 - _6013) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6165 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6171;
                if (_6165)
                {
                    _6171 = _20261.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6171 = _6165;
                }
                bool _6176;
                if (_6171)
                {
                    bool _12071 = all(bool2(_19694.x > 0.0f.xx.x, _19694.y > 0.0f.xx.y));
                    bool _12077;
                    if (_12071)
                    {
                        _12077 = all(bool2(_19694.x < 1.0f.xx.x, _19694.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12077 = _12071;
                    }
                    _6176 = _12077;
                }
                else
                {
                    _6176 = _6171;
                }
                bool _6184;
                if (_6176)
                {
                    uint _12084_dummy_parameter;
                    _6184 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19694 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12084_dummy_parameter))))), 0)).x) > _12066;
                }
                else
                {
                    _6184 = _6176;
                }
                float4 _20370;
                if (_6184)
                {
                    float4 _19389 = _20359;
                    _19389.w = 0.0f;
                    _20370 = _19389;
                }
                else
                {
                    _20370 = _20359;
                }
                bool _6191 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6197;
                if (_6191)
                {
                    _6197 = _20261.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6197 = _6191;
                }
                bool _6202;
                if (_6197)
                {
                    bool _12102 = all(bool2(_19693.x > 0.0f.xx.x, _19693.y > 0.0f.xx.y));
                    bool _12108;
                    if (_12102)
                    {
                        _12108 = all(bool2(_19693.x < 1.0f.xx.x, _19693.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12108 = _12102;
                    }
                    _6202 = _12108;
                }
                else
                {
                    _6202 = _6197;
                }
                bool _6210;
                if (_6202)
                {
                    uint _12115_dummy_parameter;
                    _6210 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19693 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12115_dummy_parameter))))), 0)).x) > _12066;
                }
                else
                {
                    _6210 = _6202;
                }
                float4 _20373;
                if (_6210)
                {
                    float4 _19392 = _20370;
                    _19392.z = 0.0f;
                    _20373 = _19392;
                }
                else
                {
                    _20373 = _20370;
                }
                _20372 = _20373;
            }
            else
            {
                _20372 = _20359;
            }
            float4 _20444;
            if (any(bool4(_20372.x < 1.0f.xxxx.x, _20372.y < 1.0f.xxxx.y, _20372.z < 1.0f.xxxx.z, _20372.w < 1.0f.xxxx.w)))
            {
                float4 _6221 = _20261 * _20372;
                float _6223 = dot(_6221, 1.0f.xxxx);
                float4 _20445;
                if (_6223 > 0.0f)
                {
                    _20445 = _6221 / _6223.xxxx;
                }
                else
                {
                    bool _6234 = _20372.y == 0.0f;
                    bool _6240;
                    if (_6234)
                    {
                        _6240 = _20372.x > 0.0f;
                    }
                    else
                    {
                        _6240 = _6234;
                    }
                    bool _6245;
                    if (_6240)
                    {
                        bool _12133 = all(bool2(_19690.x > 0.0f.xx.x, _19690.y > 0.0f.xx.y));
                        bool _12139;
                        if (_12133)
                        {
                            _12139 = all(bool2(_19690.x < 1.0f.xx.x, _19690.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12139 = _12133;
                        }
                        _6245 = _12139;
                    }
                    else
                    {
                        _6245 = _6240;
                    }
                    float4 _20446;
                    if (_6245)
                    {
                        _20446 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6250 = _20372.x == 0.0f;
                        bool _6256;
                        if (_6250)
                        {
                            _6256 = _20372.y > 0.0f;
                        }
                        else
                        {
                            _6256 = _6250;
                        }
                        bool _6261;
                        if (_6256)
                        {
                            bool _12144 = all(bool2(_19692.x > 0.0f.xx.x, _19692.y > 0.0f.xx.y));
                            bool _12150;
                            if (_12144)
                            {
                                _12150 = all(bool2(_19692.x < 1.0f.xx.x, _19692.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12150 = _12144;
                            }
                            _6261 = _12150;
                        }
                        else
                        {
                            _6261 = _6256;
                        }
                        bool4 _23583 = _6261.xxxx;
                        _20446 = float4(_23583.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20261.x, _23583.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20261.y, _23583.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20261.z, _23583.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20261.w);
                    }
                    _20445 = _20446;
                }
                _20444 = _20445;
            }
            else
            {
                _20444 = _20261;
            }
            _20443 = _20444;
        }
        else
        {
            _20443 = _20266;
        }
        float4 _21173;
        bool _21479;
        float3 _21668;
        if (((cbFI_pad0 & 32768u) != 0u) && _5970)
        {
            bool _6278 = _20443.x > 0.00999999977648258209228515625f;
            bool _6281 = _20443.y > 0.00999999977648258209228515625f;
            bool _6290 = (_20443.z + _20443.w) > 0.0199999995529651641845703125f;
            bool _6296;
            if (_6290)
            {
                bool _12155 = all(bool2(_19693.x > 0.0f.xx.x, _19693.y > 0.0f.xx.y));
                bool _12161;
                if (_12155)
                {
                    _12161 = all(bool2(_19693.x < 1.0f.xx.x, _19693.y < 1.0f.xx.y));
                }
                else
                {
                    _12161 = _12155;
                }
                _6296 = _12161;
            }
            else
            {
                _6296 = _6290;
            }
            bool _6301;
            if (_6296)
            {
                bool _12166 = all(bool2(_19694.x > 0.0f.xx.x, _19694.y > 0.0f.xx.y));
                bool _12172;
                if (_12166)
                {
                    _12172 = all(bool2(_19694.x < 1.0f.xx.x, _19694.y < 1.0f.xx.y));
                }
                else
                {
                    _12172 = _12166;
                }
                _6301 = _12172;
            }
            else
            {
                _6301 = _6296;
            }
            bool _6308;
            if (_6301)
            {
                float _20459;
                do
                {
                    bool _12255 = all(bool2(_19693.x > 0.0f.xx.x, _19693.y > 0.0f.xx.y));
                    bool _12261;
                    if (_12255)
                    {
                        _12261 = all(bool2(_19693.x < 1.0f.xx.x, _19693.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12261 = _12255;
                    }
                    bool _12192 = !_12261;
                    bool _12199;
                    if (!_12192)
                    {
                        bool _12266 = all(bool2(_19694.x > 0.0f.xx.x, _19694.y > 0.0f.xx.y));
                        bool _12272;
                        if (_12266)
                        {
                            _12272 = all(bool2(_19694.x < 1.0f.xx.x, _19694.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12272 = _12266;
                        }
                        _12199 = !_12272;
                    }
                    else
                    {
                        _12199 = _12192;
                    }
                    if (_12199)
                    {
                        _20459 = 0.0f;
                        break;
                    }
                    uint _12279_dummy_parameter;
                    uint _12295_dummy_parameter;
                    float4x4 _20458;
                    do
                    {
                        float4x4 _12309;
                        bool _20457;
                        do
                        {
                            _12309 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20457 = false;
                                break;
                            }
                            uint _12343 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12343 + 32u) * 4 + 0) != 1u)
                            {
                                _20457 = false;
                                break;
                            }
                            uint _20454;
                            _20454 = 0u;
                            for (; _20454 < 4u; _20454++)
                            {
                                for (uint _20455 = 0u; _20455 < 4u; )
                                {
                                    _12309[_20454][_20455] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12343 + 16u) + (_20454 * 4u)) + _20455) * 4 + 0));
                                    _20455++;
                                    continue;
                                }
                            }
                            _20457 = true;
                            break;
                        } while(false);
                        if (_20457)
                        {
                            _20458 = _12309;
                            break;
                        }
                        _20458 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12220 = mul(float4((float2(_19693.x, 1.0f - _19693.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19693 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12279_dummy_parameter))))), 0)).x, 1.0f), _20458);
                    float _12222 = _12220.w;
                    if (abs(_12222) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20459 = 0.0f;
                        break;
                    }
                    float _12233 = abs(cbFI_DeviceToViewDepth.y / ((_12220.z / _12222) - cbFI_DeviceToViewDepth.x));
                    float _12236 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19694 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12295_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20459 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12233 - _12236) / max(max(_12233, _12236), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6308 = _20459 < 0.5f;
            }
            else
            {
                _6308 = _6301;
            }
            float4 _20478;
            if (_6308)
            {
                uint _12447_dummy_parameter;
                uint _12478_dummy_parameter;
                float4 _20479;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19693 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12447_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19694 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12478_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20479 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20479 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20478 = _20479;
            }
            else
            {
                _20478 = 1.0f.xxxx;
            }
            bool _6332;
            if (_10912)
            {
                bool _12507 = all(bool2(_19690.x > 0.0f.xx.x, _19690.y > 0.0f.xx.y));
                bool _12513;
                if (_12507)
                {
                    _12513 = all(bool2(_19690.x < 1.0f.xx.x, _19690.y < 1.0f.xx.y));
                }
                else
                {
                    _12513 = _12507;
                }
                _6332 = _12513;
            }
            else
            {
                _6332 = _10912;
            }
            bool _6338;
            if (_10912)
            {
                bool _12518 = all(bool2(_19692.x > 0.0f.xx.x, _19692.y > 0.0f.xx.y));
                bool _12524;
                if (_12518)
                {
                    _12524 = all(bool2(_19692.x < 1.0f.xx.x, _19692.y < 1.0f.xx.y));
                }
                else
                {
                    _12524 = _12518;
                }
                _6338 = _12524;
            }
            else
            {
                _6338 = _10912;
            }
            bool _6344;
            if (_10944)
            {
                bool _12529 = all(bool2(_19693.x > 0.0f.xx.x, _19693.y > 0.0f.xx.y));
                bool _12535;
                if (_12529)
                {
                    _12535 = all(bool2(_19693.x < 1.0f.xx.x, _19693.y < 1.0f.xx.y));
                }
                else
                {
                    _12535 = _12529;
                }
                _6344 = _12535;
            }
            else
            {
                _6344 = _10944;
            }
            bool _6350;
            if (_10944)
            {
                bool _12540 = all(bool2(_19694.x > 0.0f.xx.x, _19694.y > 0.0f.xx.y));
                bool _12546;
                if (_12540)
                {
                    _12546 = all(bool2(_19694.x < 1.0f.xx.x, _19694.y < 1.0f.xx.y));
                }
                else
                {
                    _12546 = _12540;
                }
                _6350 = _12546;
            }
            else
            {
                _6350 = _10944;
            }
            bool _6353 = _6344 != _6350;
            bool _6359;
            if (_6353)
            {
                _6359 = _6332 || _6338;
            }
            else
            {
                _6359 = _6353;
            }
            float4 _20581;
            if (_6359)
            {
                float4 _19419 = _20478;
                _19419.z = 0.0f;
                _19419.w = 0.0f;
                _20581 = _19419;
            }
            else
            {
                _20581 = _20478;
            }
            bool _6366 = _6332 && _6278;
            bool _6369 = _6338 && _6281;
            float4 _20686;
            float3 _21777;
            if (_6366 || _6369)
            {
                float _20576;
                do
                {
                    uint4 _12685 = r_warped_motion_qdata_tp1.Load(int3(_19911, 0));
                    uint _12686 = _12685.x;
                    if (_12686 != 0u)
                    {
                        float _20575;
                        if (_12686 == 0u)
                        {
                            _20575 = -1.0f;
                        }
                        else
                        {
                            _20575 = float((_12686 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20576 = _20575;
                        break;
                    }
                    int _20558;
                    uint _20559;
                    _20559 = _12686;
                    _20558 = -1;
                    uint _20574;
                    for (; _20558 <= 1; _20559 = _20574, _20558++)
                    {
                        _20574 = _20559;
                        for (int _20572 = -1; _20572 <= 1; )
                        {
                            _20574 = max(_20574, r_warped_motion_qdata_tp1.Load(int3(clamp(_19911 + int2(_20572, _20558), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20572++;
                            continue;
                        }
                    }
                    if (_20559 != 0u)
                    {
                        float _20571;
                        if (_20559 == 0u)
                        {
                            _20571 = -1.0f;
                        }
                        else
                        {
                            _20571 = float((_20559 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20576 = _20571;
                        break;
                    }
                    uint _20561;
                    _20561 = 4294967295u;
                    uint _23212;
                    for (int _20560 = 0; _20560 < 8; _20561 = _23212, _20560++)
                    {
                        int _20564 = 0;
                        for (;;)
                        {
                            if (_20564 < 5)
                            {
                                int2 _12636 = _19911 + (_1239[_20560] * _1248[_20564].xx);
                                bool _12639 = any(bool2(_12636.x < int2(0, 0).x, _12636.y < int2(0, 0).y));
                                bool _12647;
                                if (!_12639)
                                {
                                    _12647 = any(bool2(_12636.x >= cbFI_MvDepthLaneSize.x, _12636.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12647 = _12639;
                                }
                                if (_12647)
                                {
                                    _23212 = _20561;
                                    break;
                                }
                                uint4 _12725 = r_warped_motion_qdata_tp1.Load(int3(_12636, 0));
                                uint _12726 = _12725.x;
                                if (_12726 != 0u)
                                {
                                    _23212 = min(_20561, _12726);
                                    break;
                                }
                                _20564++;
                                continue;
                            }
                            else
                            {
                                _23212 = _20561;
                                break;
                            }
                        }
                    }
                    float _20563;
                    if (_20561 == 4294967295u)
                    {
                        _20563 = -1.0f;
                    }
                    else
                    {
                        float _20562;
                        if (_20561 == 0u)
                        {
                            _20562 = -1.0f;
                        }
                        else
                        {
                            _20562 = float((_20561 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20563 = _20562;
                    }
                    _20576 = _20563;
                    break;
                } while(false);
                bool _6377 = _20576 < 0.0f;
                float _20577;
                if (_6377)
                {
                    _20577 = 0.0f;
                }
                else
                {
                    _20577 = _20576 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12747_dummy_parameter;
                uint _12779_dummy_parameter;
                float4 _20614;
                if ((_6377 && _6366) && _6369)
                {
                    uint _12811_dummy_parameter;
                    float _12835 = log(((r_depth_tm1.Load(int3(int2(floor(_19690 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12811_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12843_dummy_parameter;
                    float _12867 = log(((r_depth_tp1.Load(int3(int2(floor(_19692 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12843_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20615;
                    if (_12835 > (_12867 + 0.07999999821186065673828125f))
                    {
                        float4 _19423 = _20581;
                        _19423.x = 0.0f;
                        _20615 = _19423;
                    }
                    else
                    {
                        float4 _20616;
                        if (_12867 > (_12835 + 0.07999999821186065673828125f))
                        {
                            float4 _19425 = _20581;
                            _19425.y = 0.0f;
                            _20616 = _19425;
                        }
                        else
                        {
                            _20616 = _20581;
                        }
                        _20615 = _20616;
                    }
                    _20614 = _20615;
                }
                else
                {
                    _20614 = _20581;
                }
                float _6429 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6431 = _20576 >= 0.0f;
                float _20597;
                if (_6431)
                {
                    _20597 = _20576 - _6429;
                }
                else
                {
                    float _20593;
                    if (_6366)
                    {
                        float _20592;
                        _20592 = 2.0f;
                        float _12925;
                        for (int _20591 = 0; _20591 < 24; _20592 = _12925, _20591++)
                        {
                            float _12889 = float(_20591 & 7) * 0.785398185253143310546875f;
                            int _12891 = _20591 >> 3;
                            int _20594;
                            if (_12891 == 0)
                            {
                                _20594 = 16;
                            }
                            else
                            {
                                _20594 = (_12891 == 1) ? 48 : 96;
                            }
                            uint _12941_dummy_parameter;
                            _12925 = min(_20592, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19690 + ((cbFI_MvDepthLaneSizeRcp * float(_20594)) * float2(cos(_12889), sin(_12889))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12941_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20593 = _20592;
                    }
                    else
                    {
                        _20593 = 0.0f;
                    }
                    _20597 = _20593;
                }
                float _20604;
                if (_6431)
                {
                    _20604 = _20576 - _6429;
                }
                else
                {
                    float _20600;
                    if (_6369)
                    {
                        float _20599;
                        _20599 = 2.0f;
                        float _13039;
                        for (int _20598 = 0; _20598 < 24; _20599 = _13039, _20598++)
                        {
                            float _13003 = float(_20598 & 7) * 0.785398185253143310546875f;
                            int _13005 = _20598 >> 3;
                            int _20601;
                            if (_13005 == 0)
                            {
                                _20601 = 16;
                            }
                            else
                            {
                                _20601 = (_13005 == 1) ? 48 : 96;
                            }
                            uint _13071_dummy_parameter;
                            _13039 = min(_20599, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19692 + ((cbFI_MvDepthLaneSizeRcp * float(_20601)) * float2(cos(_13003), sin(_13003))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13071_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20600 = _20599;
                    }
                    else
                    {
                        _20600 = 0.0f;
                    }
                    _20604 = _20600;
                }
                float _20605;
                if (_6366)
                {
                    uint _13103_dummy_parameter;
                    _20605 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_19690 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13103_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20605 = 0.0f;
                }
                float _20606;
                if (_6369)
                {
                    uint _13123_dummy_parameter;
                    _20606 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_19692 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13123_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20606 = 0.0f;
                }
                bool _6486;
                if (_6366)
                {
                    _6486 = _20605 > ((exp((_20597 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6486 = _6366;
                }
                float4 _20622;
                if (_6486)
                {
                    float4 _19427 = _20614;
                    _19427.x = 0.0f;
                    _20622 = _19427;
                }
                else
                {
                    _20622 = _20614;
                }
                bool _6498;
                if (_6369)
                {
                    _6498 = _20606 > ((exp((_20604 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6498 = _6369;
                }
                float4 _20624;
                if (_6498)
                {
                    float4 _19429 = _20622;
                    _19429.y = 0.0f;
                    _20624 = _19429;
                }
                else
                {
                    _20624 = _20622;
                }
                float4 _20687;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6431)
                {
                    bool _6518;
                    if (_6366)
                    {
                        _6518 = _20605 < ((exp((_20597 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6518 = _6366;
                    }
                    float4 _20626;
                    if (_6518)
                    {
                        float4 _19431 = _20624;
                        _19431.x = 0.0f;
                        _20626 = _19431;
                    }
                    else
                    {
                        _20626 = _20624;
                    }
                    bool _6530;
                    if (_6369)
                    {
                        _6530 = _20606 < ((exp((_20604 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6530 = _6369;
                    }
                    float4 _20688;
                    if (_6530)
                    {
                        float4 _19433 = _20626;
                        _19433.y = 0.0f;
                        _20688 = _19433;
                    }
                    else
                    {
                        _20688 = _20626;
                    }
                    _20687 = _20688;
                }
                else
                {
                    _20687 = _20624;
                }
                _21777 = float3(_20577, log(((r_depth_tm1.Load(int3(int2(floor(_19690 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12747_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_19692 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12779_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _20686 = _20687;
            }
            else
            {
                _21777 = float3(0.0f, 0.0f, 0.5f);
                _20686 = _20581;
            }
            bool _6541 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6290;
            bool _6547;
            if (_6541)
            {
                _6547 = _6344 || _6350;
            }
            else
            {
                _6547 = _6541;
            }
            float4 _20729;
            if (_6547)
            {
                float _20681;
                do
                {
                    uint4 _13303 = r_warped_motion_qdata_tp1.Load(int3(_19911, 0));
                    uint _13304 = _13303.x;
                    if (_13304 != 0u)
                    {
                        float _20680;
                        if (_13304 == 0u)
                        {
                            _20680 = -1.0f;
                        }
                        else
                        {
                            _20680 = float((_13304 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20681 = _20680;
                        break;
                    }
                    int _20663;
                    uint _20664;
                    _20664 = _13304;
                    _20663 = -1;
                    uint _20679;
                    for (; _20663 <= 1; _20664 = _20679, _20663++)
                    {
                        _20679 = _20664;
                        for (int _20677 = -1; _20677 <= 1; )
                        {
                            _20679 = max(_20679, r_warped_motion_qdata_tp1.Load(int3(clamp(_19911 + int2(_20677, _20663), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20677++;
                            continue;
                        }
                    }
                    if (_20664 != 0u)
                    {
                        float _20676;
                        if (_20664 == 0u)
                        {
                            _20676 = -1.0f;
                        }
                        else
                        {
                            _20676 = float((_20664 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20681 = _20676;
                        break;
                    }
                    uint _20666;
                    _20666 = 4294967295u;
                    uint _23213;
                    for (int _20665 = 0; _20665 < 8; _20666 = _23213, _20665++)
                    {
                        int _20669 = 0;
                        for (;;)
                        {
                            if (_20669 < 5)
                            {
                                int2 _13254 = _19911 + (_1239[_20665] * _1248[_20669].xx);
                                bool _13257 = any(bool2(_13254.x < int2(0, 0).x, _13254.y < int2(0, 0).y));
                                bool _13265;
                                if (!_13257)
                                {
                                    _13265 = any(bool2(_13254.x >= cbFI_MvDepthLaneSize.x, _13254.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13265 = _13257;
                                }
                                if (_13265)
                                {
                                    _23213 = _20666;
                                    break;
                                }
                                uint4 _13343 = r_warped_motion_qdata_tp1.Load(int3(_13254, 0));
                                uint _13344 = _13343.x;
                                if (_13344 != 0u)
                                {
                                    _23213 = min(_20666, _13344);
                                    break;
                                }
                                _20669++;
                                continue;
                            }
                            else
                            {
                                _23213 = _20666;
                                break;
                            }
                        }
                    }
                    float _20668;
                    if (_20666 == 4294967295u)
                    {
                        _20668 = -1.0f;
                    }
                    else
                    {
                        float _20667;
                        if (_20666 == 0u)
                        {
                            _20667 = -1.0f;
                        }
                        else
                        {
                            _20667 = float((_20666 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20668 = _20667;
                    }
                    _20681 = _20668;
                    break;
                } while(false);
                float4 _20730;
                if (_20681 >= 0.0f)
                {
                    float _13365 = (exp((_20681 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6566;
                    if (_6344)
                    {
                        uint _13372_dummy_parameter;
                        _6566 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19693 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13372_dummy_parameter))))), 0)).x) > _13365;
                    }
                    else
                    {
                        _6566 = _6344;
                    }
                    float4 _20699;
                    if (_6566)
                    {
                        float4 _19435 = _20686;
                        _19435.z = 0.0f;
                        _20699 = _19435;
                    }
                    else
                    {
                        _20699 = _20686;
                    }
                    bool _6578;
                    if (_6350)
                    {
                        uint _13392_dummy_parameter;
                        _6578 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19694 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13392_dummy_parameter))))), 0)).x) > _13365;
                    }
                    else
                    {
                        _6578 = _6350;
                    }
                    float4 _20731;
                    if (_6578)
                    {
                        float4 _19437 = _20699;
                        _19437.w = 0.0f;
                        _20731 = _19437;
                    }
                    else
                    {
                        _20731 = _20699;
                    }
                    _20730 = _20731;
                }
                else
                {
                    _20730 = _20686;
                }
                _20729 = _20730;
            }
            else
            {
                _20729 = _20686;
            }
            bool _6586 = _6332 != _6338;
            bool _6593;
            if (_6586)
            {
                _6593 = _6332 ? _6278 : _6281;
            }
            else
            {
                _6593 = _6586;
            }
            bool _6600;
            if (_6593)
            {
                _6600 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6600 = _6593;
            }
            float4 _20832;
            if (_6600)
            {
                bool2 _6605 = _6332.xx;
                float2 _6606 = float2(_6605.x ? _19690.x : _19692.x, _6605.y ? _19690.y : _19692.y);
                float _20713;
                if (_6332)
                {
                    uint _13412_dummy_parameter;
                    _20713 = r_depth_tm1.Load(int3(int2(floor(_6606 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13412_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13428_dummy_parameter;
                    _20713 = r_depth_tp1.Load(int3(int2(floor(_6606 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13428_dummy_parameter))))), 0)).x;
                }
                float4x4 _20720;
                if (_6332)
                {
                    float4x4 _20709;
                    do
                    {
                        float4x4 _13442;
                        bool _20708;
                        do
                        {
                            _13442 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20708 = false;
                                break;
                            }
                            uint _13476 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13476 + 32u) * 4 + 0) != 1u)
                            {
                                _20708 = false;
                                break;
                            }
                            uint _20705;
                            _20705 = 0u;
                            for (; _20705 < 4u; _20705++)
                            {
                                for (uint _20706 = 0u; _20706 < 4u; )
                                {
                                    _13442[_20705][_20706] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13476 + 16u) + (_20705 * 4u)) + _20706) * 4 + 0));
                                    _20706++;
                                    continue;
                                }
                            }
                            _20708 = true;
                            break;
                        } while(false);
                        if (_20708)
                        {
                            _20709 = _13442;
                            break;
                        }
                        _20709 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20720 = _20709;
                }
                else
                {
                    float4x4 _20704;
                    do
                    {
                        float4x4 _13548;
                        bool _20703;
                        do
                        {
                            _13548 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20703 = false;
                                break;
                            }
                            uint _13582 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13582 + 32u) * 4 + 0) != 1u)
                            {
                                _20703 = false;
                                break;
                            }
                            uint _20700;
                            _20700 = 0u;
                            for (; _20700 < 4u; _20700++)
                            {
                                for (uint _20701 = 0u; _20701 < 4u; )
                                {
                                    _13548[_20700][_20701] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13582 + (_20700 * 4u)) + _20701) * 4 + 0));
                                    _20701++;
                                    continue;
                                }
                            }
                            _20703 = true;
                            break;
                        } while(false);
                        if (_20703)
                        {
                            _20704 = _13548;
                            break;
                        }
                        _20704 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20720 = _20704;
                }
                float2 _20721;
                do
                {
                    float _13659 = _6606.x;
                    float _13662 = 1.0f - _6606.y;
                    float4 _13673 = mul(float4((float2(_13659, _13662) * 2.0f) - 1.0f.xx, _20713, 1.0f), _20720);
                    float _13675 = _13673.w;
                    if (!(_13675 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20721 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13688 = ((_13673.xy / _13675.xx) + 1.0f.xx) * 0.5f;
                    _20721 = float2(_13688.x - _13659, _13662 - _13688.y);
                    break;
                } while(false);
                float2 _6636 = float2(cbFI_DisplaySize);
                float4 _20833;
                if (!(length(((_6606 + _20721) - float2(_6605.x ? _19692.x : _19690.x, _6605.y ? _19692.y : _19690.y)) * _6636) <= ((0.100000001490116119384765625f * length(_20721 * _6636)) + 8.0f)))
                {
                    float4 _20834;
                    if (_6332)
                    {
                        float4 _19447 = _20729;
                        _19447.x = 0.0f;
                        _20834 = _19447;
                    }
                    else
                    {
                        float4 _19449 = _20729;
                        _19449.y = 0.0f;
                        _20834 = _19449;
                    }
                    _20833 = _20834;
                }
                else
                {
                    _20833 = _20729;
                }
                _20832 = _20833;
            }
            else
            {
                _20832 = _20729;
            }
            float4 _6661 = _20443 * _20832;
            float _6663 = dot(_6661, 1.0f.xxxx);
            float4 _21174;
            bool _21480;
            if (_6663 > 0.0f)
            {
                _21480 = _20134;
                _21174 = _6661 / _6663.xxxx;
            }
            else
            {
                bool _6674 = any(bool4(_20832.x < 1.0f.xxxx.x, _20832.y < 1.0f.xxxx.y, _20832.z < 1.0f.xxxx.z, _20832.w < 1.0f.xxxx.w));
                if (_6674)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13710;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13710);
                    }
                }
                bool4 _23586 = _6674.xxxx;
                _21480 = _6674 ? true : _20134;
                _21174 = float4(_23586.x ? 0.0f.xxxx.x : _20443.x, _23586.y ? 0.0f.xxxx.y : _20443.y, _23586.z ? 0.0f.xxxx.z : _20443.z, _23586.w ? 0.0f.xxxx.w : _20443.w);
            }
            _21668 = _21777;
            _21479 = _21480;
            _21173 = _21174;
        }
        else
        {
            _21668 = float3(0.0f, 0.0f, 0.5f);
            _21479 = _20134;
            _21173 = _20443;
        }
        uint _6683 = (cbFI_pad0 >> 24u) & 31u;
        uint _6687 = (cbFI_pad0 >> 16u) & 255u;
        bool _6689 = _6683 != 0u;
        bool _6691 = _6687 == 12u;
        bool _6694 = _6687 == 13u;
        float4 _21194;
        if ((_6689 || _6691) || _6694)
        {
            float _20840;
            do
            {
                bool _13794 = all(bool2(_19693.x > 0.0f.xx.x, _19693.y > 0.0f.xx.y));
                bool _13800;
                if (_13794)
                {
                    _13800 = all(bool2(_19693.x < 1.0f.xx.x, _19693.y < 1.0f.xx.y));
                }
                else
                {
                    _13800 = _13794;
                }
                bool _13731 = !_13800;
                bool _13738;
                if (!_13731)
                {
                    bool _13805 = all(bool2(_19694.x > 0.0f.xx.x, _19694.y > 0.0f.xx.y));
                    bool _13811;
                    if (_13805)
                    {
                        _13811 = all(bool2(_19694.x < 1.0f.xx.x, _19694.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13811 = _13805;
                    }
                    _13738 = !_13811;
                }
                else
                {
                    _13738 = _13731;
                }
                if (_13738)
                {
                    _20840 = 0.0f;
                    break;
                }
                uint _13818_dummy_parameter;
                uint _13834_dummy_parameter;
                float4x4 _20839;
                do
                {
                    float4x4 _13848;
                    bool _20838;
                    do
                    {
                        _13848 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20838 = false;
                            break;
                        }
                        uint _13882 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_13882 + 32u) * 4 + 0) != 1u)
                        {
                            _20838 = false;
                            break;
                        }
                        uint _20835;
                        _20835 = 0u;
                        for (; _20835 < 4u; _20835++)
                        {
                            for (uint _20836 = 0u; _20836 < 4u; )
                            {
                                _13848[_20835][_20836] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13882 + 16u) + (_20835 * 4u)) + _20836) * 4 + 0));
                                _20836++;
                                continue;
                            }
                        }
                        _20838 = true;
                        break;
                    } while(false);
                    if (_20838)
                    {
                        _20839 = _13848;
                        break;
                    }
                    _20839 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13759 = mul(float4((float2(_19693.x, 1.0f - _19693.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19693 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13818_dummy_parameter))))), 0)).x, 1.0f), _20839);
                float _13761 = _13759.w;
                if (abs(_13761) < 9.9999999747524270787835121154785e-07f)
                {
                    _20840 = 0.0f;
                    break;
                }
                float _13772 = abs(cbFI_DeviceToViewDepth.y / ((_13759.z / _13761) - cbFI_DeviceToViewDepth.x));
                float _13775 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19694 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13834_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20840 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13772 - _13775) / max(max(_13772, _13775), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _13984 = all(bool2(_19694.x > 0.0f.xx.x, _19694.y > 0.0f.xx.y));
            bool _13990;
            if (_13984)
            {
                _13990 = all(bool2(_19694.x < 1.0f.xx.x, _19694.y < 1.0f.xx.y));
            }
            else
            {
                _13990 = _13984;
            }
            float _20841;
            if (_13990)
            {
                uint _13997_dummy_parameter;
                _20841 = length((_7810 + (r_motion_tp1.Load(int3(int2(floor(_19694 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _13997_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20841 = 1000000.0f;
            }
            float _20856;
            if ((_6683 & 1u) != 0u)
            {
                _20856 = _20840;
            }
            else
            {
                _20856 = 1.0f;
            }
            float _20857;
            if ((_6683 & 2u) != 0u)
            {
                _20857 = _20856 * (1.0f - smoothstep(2.0f, 8.0f, _20841));
            }
            else
            {
                _20857 = _20856;
            }
            float _20858;
            if ((_6683 & 4u) != 0u)
            {
                _20858 = _20857 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8531 - _8539) - length(_8515 - _8523))));
            }
            else
            {
                _20858 = _20857;
            }
            float _21188;
            if ((_6683 & 8u) != 0u)
            {
                _21188 = lerp(1.0f, _20858, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8515 - _8523)));
            }
            else
            {
                _21188 = _20858;
            }
            bool _6769 = (_6683 & 16u) != 0u;
            bool _6778;
            if (_6769)
            {
                _6778 = length(_19688 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6778 = _6769;
            }
            float _23588 = _6778 ? 1.0f : _21188;
            bool _6784 = _6689 && _10912;
            bool _6789;
            if (_6784)
            {
                bool _14022 = all(bool2(_19690.x > 0.0f.xx.x, _19690.y > 0.0f.xx.y));
                bool _14028;
                if (_14022)
                {
                    _14028 = all(bool2(_19690.x < 1.0f.xx.x, _19690.y < 1.0f.xx.y));
                }
                else
                {
                    _14028 = _14022;
                }
                _6789 = _14028;
            }
            else
            {
                _6789 = _6784;
            }
            bool _6794;
            if (_6789)
            {
                bool _14033 = all(bool2(_19692.x > 0.0f.xx.x, _19692.y > 0.0f.xx.y));
                bool _14039;
                if (_14033)
                {
                    _14039 = all(bool2(_19692.x < 1.0f.xx.x, _19692.y < 1.0f.xx.y));
                }
                else
                {
                    _14039 = _14033;
                }
                _6794 = _14039;
            }
            else
            {
                _6794 = _6789;
            }
            float4 _21195;
            if (_6794)
            {
                float _6800 = _21173.x + _21173.y;
                float _6809 = (_21173.z + _21173.w) * (1.0f - _23588);
                float _21191;
                if (_6800 > 9.9999997473787516355514526367188e-06f)
                {
                    _21191 = _21173.x / _6800;
                }
                else
                {
                    _21191 = _5539;
                }
                _21195 = float4(_21173.x + (_6809 * _21191), _21173.y + (_6809 * (1.0f - _21191)), _21173.zw * _23588);
            }
            else
            {
                _21195 = _21173;
            }
            _21194 = _21195;
        }
        else
        {
            _21194 = _21173;
        }
        float3 _6870 = (((_8515 * _21194.x) + (_8523 * _21194.y)) + (_8531 * _21194.z)) + (_8539 * _21194.w);
        float3 _22787;
        if (_5555 && (_21209 > 0.0f))
        {
            uint _14046_dummy_parameter;
            float2 _14061 = r_motion_tp1.Load(int3(int2(floor(_5314 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14046_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21471;
            if (_7838)
            {
                float2 _14106 = clamp((((_19667 + (_14061 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14109 = tan(_14106.x);
                _21471 = (float2(_14109 / cbFI_DeviceToViewDepth.z, (tan(_14106.y) * sqrt(1.0f + (_14109 * _14109))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21471 = _19667 + (_14061 * cbFI_Timestep);
            }
            float2 _21472;
            if (_7838)
            {
                float2 _14185 = clamp((((_19667 + (_14061 * _5529)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14188 = tan(_14185.x);
                _21472 = (float2(_14188 / cbFI_DeviceToViewDepth.z, (tan(_14185.y) * sqrt(1.0f + (_14188 * _14188))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21472 = _19667 + (_14061 * _5529);
            }
            _22787 = lerp(_6870, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21471, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21472, 0.0f).xyz, cbFI_Timestep.xxx), _21209.xxx);
        }
        else
        {
            _22787 = _6870;
        }
        float3 _22786;
        if (_21479)
        {
            float3 _14230 = r_current_interpolation_source.Load(int3(_4821, 0)).xyz;
            float3 _22788;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _10912)
            {
                uint _14237_dummy_parameter;
                float _21602;
                _21602 = r_depth_tm1.Load(int3(int2(floor(_19690 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14237_dummy_parameter))))), 0)).x;
                float _6951;
                for (int _21601 = 0; _21601 < 24; _21602 = _6951, _21601++)
                {
                    float _6923 = float(_21601 & 7) * 0.785398185253143310546875f;
                    int _6925 = _21601 >> 3;
                    int _23055;
                    if (_6925 == 0)
                    {
                        _23055 = 16;
                    }
                    else
                    {
                        _23055 = (_6925 == 1) ? 48 : 96;
                    }
                    uint _14257_dummy_parameter;
                    _6951 = max(_21602, r_depth_tm1.Load(int3(int2(floor(clamp(_19690 + ((cbFI_MvDepthLaneSizeRcp * float(_23055)) * float2(cos(_6923), sin(_6923))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14257_dummy_parameter))))), 0)).x);
                }
                float2 _21603;
                do
                {
                    float _14279 = 1.0f - _19690.y;
                    float4 _14290 = mul(float4((float2(_19690.x, _14279) * 2.0f) - 1.0f.xx, _21602, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14292 = _14290.w;
                    if (!(_14292 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21603 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14305 = ((_14290.xy / _14292.xx) + 1.0f.xx) * 0.5f;
                    _21603 = float2(_14305.x - _19690.x, _14279 - _14305.y);
                    break;
                } while(false);
                float2 _6962 = _19690 + _21603;
                bool _14323 = all(bool2(_6962.x > 0.0f.xx.x, _6962.y > 0.0f.xx.y));
                bool _14329;
                if (_14323)
                {
                    _14329 = all(bool2(_6962.x < 1.0f.xx.x, _6962.y < 1.0f.xx.y));
                }
                else
                {
                    _14329 = _14323;
                }
                float3 _22789;
                if (_14329)
                {
                    float _6968 = abs(cbFI_DeviceToViewDepth.y / (_21602 - cbFI_DeviceToViewDepth.x));
                    uint _14349_dummy_parameter;
                    int2 _14349 = int2(spvTextureSize(r_depth_m2, uint(0), _14349_dummy_parameter));
                    float _6972 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6962 * float2(_14349))), int2(0, 0), _14349 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22794;
                    if (abs(_6972 - _6968) <= (0.20000000298023223876953125f * max(_6972, _6968)))
                    {
                        uint _14383_dummy_parameter;
                        int2 _14383 = int2(spvTextureSize(r_colour_m2, uint(0), _14383_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14406;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14406);
                        }
                        _22794 = r_colour_m2.Load(int3(clamp(int2(floor(_6962 * float2(_14383))), int2(0, 0), _14383 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14416;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14416);
                        }
                        _22794 = _14230;
                    }
                    _22789 = _22794;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14426;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14426);
                    }
                    _22789 = _14230;
                }
                _22788 = _22789;
            }
            else
            {
                _22788 = _14230;
            }
            _22786 = _22788;
        }
        else
        {
            _22786 = _22787;
        }
        bool _6997 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22785;
        float _22861;
        if (_6997)
        {
            bool _14641;
            float2 _7001 = float2(cbFI_DisplaySize);
            float4x4 _21610;
            do
            {
                float4x4 _14617;
                bool _21609;
                do
                {
                    _14617 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                    _14641 = (cbFI_NfruT2Flags & 524288u) == 0u;
                    if (_14641)
                    {
                        _21609 = false;
                        break;
                    }
                    uint _14651 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                    if (rw_nfru_diagnostics.Load<uint>((_14651 + 32u) * 4 + 0) != 1u)
                    {
                        _21609 = false;
                        break;
                    }
                    uint _21606;
                    _21606 = 0u;
                    for (; _21606 < 4u; _21606++)
                    {
                        for (uint _21607 = 0u; _21607 < 4u; )
                        {
                            _14617[_21606][_21607] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14651 + (_21606 * 4u)) + _21607) * 4 + 0));
                            _21607++;
                            continue;
                        }
                    }
                    _21609 = true;
                    break;
                } while(false);
                if (_21609)
                {
                    _21610 = _14617;
                    break;
                }
                _21610 = cbFI_MotionTP1ToTM1;
                break;
            } while(false);
            float _14728;
            float _14731;
            float4 _14741;
            float2 _21611;
            do
            {
                _14728 = _5314.x;
                _14731 = 1.0f - _5314.y;
                _14741 = float4((float2(_14728, _14731) * 2.0f) - 1.0f.xx, 0.99999988079071044921875f, 1.0f);
                float4 _14742 = mul(_14741, _21610);
                float _14744 = _14742.w;
                if (!(_14744 > 9.9999999747524270787835121154785e-07f))
                {
                    _21611 = 1000000.0f.xx;
                    break;
                }
                float2 _14757 = ((_14742.xy / _14744.xx) + 1.0f.xx) * 0.5f;
                _21611 = float2(_14757.x - _14728, _14731 - _14757.y);
                break;
            } while(false);
            float4x4 _21616;
            do
            {
                float4x4 _14775;
                bool _21615;
                do
                {
                    _14775 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                    if (_14641)
                    {
                        _21615 = false;
                        break;
                    }
                    uint _14809 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                    if (rw_nfru_diagnostics.Load<uint>((_14809 + 32u) * 4 + 0) != 1u)
                    {
                        _21615 = false;
                        break;
                    }
                    uint _21612;
                    _21612 = 0u;
                    for (; _21612 < 4u; _21612++)
                    {
                        for (uint _21613 = 0u; _21613 < 4u; )
                        {
                            _14775[_21612][_21613] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14809 + 16u) + (_21612 * 4u)) + _21613) * 4 + 0));
                            _21613++;
                            continue;
                        }
                    }
                    _21615 = true;
                    break;
                } while(false);
                if (_21615)
                {
                    _21616 = _14775;
                    break;
                }
                _21616 = cbFI_MotionTM1ToTP1;
                break;
            } while(false);
            float2 _21617;
            do
            {
                float4 _14900 = mul(_14741, _21616);
                float _14902 = _14900.w;
                if (!(_14902 > 9.9999999747524270787835121154785e-07f))
                {
                    _21617 = 1000000.0f.xx;
                    break;
                }
                float2 _14915 = ((_14900.xy / _14902.xx) + 1.0f.xx) * 0.5f;
                _21617 = float2(_14915.x - _14728, _14731 - _14915.y);
                break;
            } while(false);
            float2 _14478 = abs(_21611);
            bool2 _23589 = any(bool2(_14478.x > 4.0f.xx.x, _14478.y > 4.0f.xx.y)).xx;
            float2 _14484 = abs(_21617);
            bool2 _23591 = any(bool2(_14484.x > 4.0f.xx.x, _14484.y > 4.0f.xx.y)).xx;
            float2 _14929[3];
            _14929[0] = _5314;
            float2 _15045 = clamp(_5314, 0.0f.xx, 1.0f.xx);
            uint _15053_dummy_parameter;
            _14929[1] = _5314 - ((r_motion_tp1.Load(int3(int2(floor(_15045 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15053_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5539);
            _14929[2] = _5314 - (float2(_23589.x ? 0.0f.xx.x : _21611.x, _23589.y ? 0.0f.xx.y : _21611.y) * _5539);
            float _21627;
            float2 _21628;
            _21628 = _5314;
            _21627 = 1000000000.0f;
            float _23593;
            float2 _23595;
            float _23596;
            int _21626 = 0;
            float _23047 = -1.0f;
            for (; _21626 < 3; _23047 = _23593, _21628 = _23595, _21627 = _23596, _21626++)
            {
                float2 _23037;
                _23037 = _14929[_21626];
                for (int _23036 = 0; _23036 < 30; )
                {
                    uint _15669_dummy_parameter;
                    _23037 += (((_5314 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_23037, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15669_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5539)) - _23037) * 0.699999988079071044921875f);
                    _23036++;
                    continue;
                }
                float2 _16205 = clamp(_23037, 0.0f.xx, 1.0f.xx);
                uint _16213_dummy_parameter;
                bool _16749 = all(bool2(_23037.x > 0.0f.xx.x, _23037.y > 0.0f.xx.y));
                bool _16755;
                if (_16749)
                {
                    _16755 = all(bool2(_23037.x < 1.0f.xx.x, _23037.y < 1.0f.xx.y));
                }
                else
                {
                    _16755 = _16749;
                }
                float _23039;
                if (_16755)
                {
                    _23039 = length(((_23037 + ((r_motion_tp1.Load(int3(int2(floor(_16205 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16213_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5539)) - _5314) * float2(cbFI_RenderSize));
                }
                else
                {
                    _23039 = 1000000000.0f;
                }
                uint _16766_dummy_parameter;
                float _16806 = log(((r_depth_tp1.Load(int3(int2(floor(_16205 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16766_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _15005 = _23039 < 0.3499999940395355224609375f;
                bool _15007 = _21627 < 0.3499999940395355224609375f;
                bool _15017;
                if (_15005)
                {
                    _15017 = (!_15007) || (_16806 > _23047);
                }
                else
                {
                    _15017 = _15005;
                }
                bool _15030;
                if (!_15017)
                {
                    _15030 = ((!_15005) && (!_15007)) && (_23039 < _21627);
                }
                else
                {
                    _15030 = _15017;
                }
                _23593 = _15030 ? _16806 : _23047;
                bool2 _23594 = _15030.xx;
                _23595 = float2(_23594.x ? _23037.x : _21628.x, _23594.y ? _23037.y : _21628.y);
                _23596 = _15030 ? _23039 : _21627;
            }
            float2 _16808[3];
            _16808[0] = _5314;
            float2 _21656;
            do
            {
                bool _21637;
                do
                {
                    bool _17051 = all(bool2(_15045.x > 0.0f.xx.x, _15045.y > 0.0f.xx.y));
                    bool _17057;
                    if (_17051)
                    {
                        _17057 = all(bool2(_15045.x < 1.0f.xx.x, _15045.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17057 = _17051;
                    }
                    if (!_17057)
                    {
                        _21637 = false;
                        break;
                    }
                    uint _17064_dummy_parameter;
                    float4x4 _21635;
                    do
                    {
                        float4x4 _17078;
                        bool _21634;
                        do
                        {
                            _17078 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14641)
                            {
                                _21634 = false;
                                break;
                            }
                            uint _17112 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_17112 + 32u) * 4 + 0) != 1u)
                            {
                                _21634 = false;
                                break;
                            }
                            uint _21631;
                            _21631 = 0u;
                            for (; _21631 < 4u; _21631++)
                            {
                                for (uint _21632 = 0u; _21632 < 4u; )
                                {
                                    _17078[_21631][_21632] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17112 + (_21631 * 4u)) + _21632) * 4 + 0));
                                    _21632++;
                                    continue;
                                }
                            }
                            _21634 = true;
                            break;
                        } while(false);
                        if (_21634)
                        {
                            _21635 = _17078;
                            break;
                        }
                        _21635 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _21636;
                    do
                    {
                        float _17189 = _15045.x;
                        float _17192 = 1.0f - _15045.y;
                        float4 _17203 = mul(float4((float2(_17189, _17192) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15045 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17064_dummy_parameter))))), 0)).x, 1.0f), _21635);
                        float _17205 = _17203.w;
                        if (!(_17205 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21636 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17218 = ((_17203.xy / _17205.xx) + 1.0f.xx) * 0.5f;
                        _21636 = float2(_17218.x - _17189, _17192 - _17218.y);
                        break;
                    } while(false);
                    float2 _17015 = abs(_21636);
                    if (any(bool2(_17015.x > 100000.0f.xx.x, _17015.y > 100000.0f.xx.y)))
                    {
                        _21637 = false;
                        break;
                    }
                    float _17023 = length(_21636 * _7001);
                    uint _17238_dummy_parameter;
                    bool _17037 = _17023 > ((8.0f * _7001.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _17044;
                    if (_17037)
                    {
                        _17044 = length((r_motion_tp1.Load(int3(int2(floor(_15045 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17238_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7001) < (0.20000000298023223876953125f * _17023);
                    }
                    else
                    {
                        _17044 = _17037;
                    }
                    _21637 = _17044;
                    break;
                } while(false);
                if (_21637)
                {
                    uint _17269_dummy_parameter;
                    _21656 = -(r_motion_tp1.Load(int3(int2(floor(_15045 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17269_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                    break;
                }
                uint _17296_dummy_parameter;
                float4x4 _21650;
                do
                {
                    float4x4 _17310;
                    bool _21649;
                    do
                    {
                        _17310 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_14641)
                        {
                            _21649 = false;
                            break;
                        }
                        uint _17344 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_17344 + 32u) * 4 + 0) != 1u)
                        {
                            _21649 = false;
                            break;
                        }
                        uint _21646;
                        _21646 = 0u;
                        for (; _21646 < 4u; _21646++)
                        {
                            for (uint _21647 = 0u; _21647 < 4u; )
                            {
                                _17310[_21646][_21647] = asfloat(rw_nfru_diagnostics.Load<uint>((((_17344 + 16u) + (_21646 * 4u)) + _21647) * 4 + 0));
                                _21647++;
                                continue;
                            }
                        }
                        _21649 = true;
                        break;
                    } while(false);
                    if (_21649)
                    {
                        _21650 = _17310;
                        break;
                    }
                    _21650 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float2 _21655;
                do
                {
                    float _17421 = _15045.x;
                    float _17424 = 1.0f - _15045.y;
                    float4 _17435 = mul(float4((float2(_17421, _17424) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17296_dummy_parameter))))), 0)).x, 1.0f), _21650);
                    float _17437 = _17435.w;
                    if (!(_17437 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21655 = 1000000.0f.xx;
                        break;
                    }
                    float2 _17450 = ((_17435.xy / _17437.xx) + 1.0f.xx) * 0.5f;
                    _21655 = float2(_17450.x - _17421, _17424 - _17450.y);
                    break;
                } while(false);
                float2 _16982 = abs(_21655);
                bool2 _16986 = any(bool2(_16982.x > 4.0f.xx.x, _16982.y > 4.0f.xx.y)).xx;
                _21656 = float2(_16986.x ? 0.0f.xx.x : _21655.x, _16986.y ? 0.0f.xx.y : _21655.y);
                break;
            } while(false);
            _16808[1] = _5314 - (_21656 * cbFI_Timestep);
            _16808[2] = _5314 - (float2(_23591.x ? 0.0f.xx.x : _21617.x, _23591.y ? 0.0f.xx.y : _21617.y) * cbFI_Timestep);
            float _21658;
            float2 _21659;
            _21659 = _5314;
            _21658 = 1000000000.0f;
            float _23597;
            float2 _23599;
            float _23600;
            float4x4 _17694;
            float4x4 _17926;
            float4x4 _18238;
            float4x4 _18470;
            int _21657 = 0;
            float _22949 = -1.0f;
            for (; _21657 < 3; _22949 = _23597, _21659 = _23599, _21658 = _23600, _21657++)
            {
                float2 _22882;
                _22882 = _16808[_21657];
                float2 _17504;
                for (int _22881 = 0; _22881 < 30; _22882 = _17504, _22881++)
                {
                    float2 _23007;
                    do
                    {
                        float2 _17583 = clamp(_22882, 0.0f.xx, 1.0f.xx);
                        bool _22988;
                        do
                        {
                            bool _17667 = all(bool2(_17583.x > 0.0f.xx.x, _17583.y > 0.0f.xx.y));
                            bool _17673;
                            if (_17667)
                            {
                                _17673 = all(bool2(_17583.x < 1.0f.xx.x, _17583.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _17673 = _17667;
                            }
                            if (!_17673)
                            {
                                _22988 = false;
                                break;
                            }
                            uint _17680_dummy_parameter;
                            float4x4 _22986;
                            do
                            {
                                bool _22985;
                                do
                                {
                                    _17694 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14641)
                                    {
                                        _22985 = false;
                                        break;
                                    }
                                    uint _17728 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_17728 + 32u) * 4 + 0) != 1u)
                                    {
                                        _22985 = false;
                                        break;
                                    }
                                    uint _22982;
                                    _22982 = 0u;
                                    for (; _22982 < 4u; _22982++)
                                    {
                                        for (uint _22983 = 0u; _22983 < 4u; )
                                        {
                                            _17694[_22982][_22983] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17728 + (_22982 * 4u)) + _22983) * 4 + 0));
                                            _22983++;
                                            continue;
                                        }
                                    }
                                    _22985 = true;
                                    break;
                                } while(false);
                                if (_22985)
                                {
                                    _22986 = _17694;
                                    break;
                                }
                                _22986 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _22987;
                            do
                            {
                                float _17805 = _17583.x;
                                float _17808 = 1.0f - _17583.y;
                                float4 _17819 = mul(float4((float2(_17805, _17808) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17583 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17680_dummy_parameter))))), 0)).x, 1.0f), _22986);
                                float _17821 = _17819.w;
                                if (!(_17821 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22987 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17834 = ((_17819.xy / _17821.xx) + 1.0f.xx) * 0.5f;
                                _22987 = float2(_17834.x - _17805, _17808 - _17834.y);
                                break;
                            } while(false);
                            float2 _17631 = abs(_22987);
                            if (any(bool2(_17631.x > 100000.0f.xx.x, _17631.y > 100000.0f.xx.y)))
                            {
                                _22988 = false;
                                break;
                            }
                            float _17639 = length(_22987 * _7001);
                            uint _17854_dummy_parameter;
                            bool _17653 = _17639 > ((8.0f * _7001.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _17660;
                            if (_17653)
                            {
                                _17660 = length((r_motion_tp1.Load(int3(int2(floor(_17583 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17854_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7001) < (0.20000000298023223876953125f * _17639);
                            }
                            else
                            {
                                _17660 = _17653;
                            }
                            _22988 = _17660;
                            break;
                        } while(false);
                        if (_22988)
                        {
                            uint _17885_dummy_parameter;
                            _23007 = -(r_motion_tp1.Load(int3(int2(floor(_17583 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17885_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _17912_dummy_parameter;
                        float4x4 _23001;
                        do
                        {
                            bool _23000;
                            do
                            {
                                _17926 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14641)
                                {
                                    _23000 = false;
                                    break;
                                }
                                uint _17960 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17960 + 32u) * 4 + 0) != 1u)
                                {
                                    _23000 = false;
                                    break;
                                }
                                uint _22997;
                                _22997 = 0u;
                                for (; _22997 < 4u; _22997++)
                                {
                                    for (uint _22998 = 0u; _22998 < 4u; )
                                    {
                                        _17926[_22997][_22998] = asfloat(rw_nfru_diagnostics.Load<uint>((((_17960 + 16u) + (_22997 * 4u)) + _22998) * 4 + 0));
                                        _22998++;
                                        continue;
                                    }
                                }
                                _23000 = true;
                                break;
                            } while(false);
                            if (_23000)
                            {
                                _23001 = _17926;
                                break;
                            }
                            _23001 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float2 _23006;
                        do
                        {
                            float _18037 = _17583.x;
                            float _18040 = 1.0f - _17583.y;
                            float4 _18051 = mul(float4((float2(_18037, _18040) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17583 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17912_dummy_parameter))))), 0)).x, 1.0f), _23001);
                            float _18053 = _18051.w;
                            if (!(_18053 > 9.9999999747524270787835121154785e-07f))
                            {
                                _23006 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18066 = ((_18051.xy / _18053.xx) + 1.0f.xx) * 0.5f;
                            _23006 = float2(_18066.x - _18037, _18040 - _18066.y);
                            break;
                        } while(false);
                        float2 _17598 = abs(_23006);
                        bool2 _17602 = any(bool2(_17598.x > 4.0f.xx.x, _17598.y > 4.0f.xx.y)).xx;
                        _23007 = float2(_17602.x ? 0.0f.xx.x : _23006.x, _17602.y ? 0.0f.xx.y : _23006.y);
                        break;
                    } while(false);
                    _17504 = _22882 + (((_5314 - (_23007 * cbFI_Timestep)) - _22882) * 0.699999988079071044921875f);
                }
                float2 _18127;
                float2 _22908;
                do
                {
                    _18127 = clamp(_22882, 0.0f.xx, 1.0f.xx);
                    bool _22889;
                    do
                    {
                        bool _18211 = all(bool2(_18127.x > 0.0f.xx.x, _18127.y > 0.0f.xx.y));
                        bool _18217;
                        if (_18211)
                        {
                            _18217 = all(bool2(_18127.x < 1.0f.xx.x, _18127.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _18217 = _18211;
                        }
                        if (!_18217)
                        {
                            _22889 = false;
                            break;
                        }
                        uint _18224_dummy_parameter;
                        float4x4 _22887;
                        do
                        {
                            bool _22886;
                            do
                            {
                                _18238 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14641)
                                {
                                    _22886 = false;
                                    break;
                                }
                                uint _18272 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_18272 + 32u) * 4 + 0) != 1u)
                                {
                                    _22886 = false;
                                    break;
                                }
                                uint _22883;
                                _22883 = 0u;
                                for (; _22883 < 4u; _22883++)
                                {
                                    for (uint _22884 = 0u; _22884 < 4u; )
                                    {
                                        _18238[_22883][_22884] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18272 + (_22883 * 4u)) + _22884) * 4 + 0));
                                        _22884++;
                                        continue;
                                    }
                                }
                                _22886 = true;
                                break;
                            } while(false);
                            if (_22886)
                            {
                                _22887 = _18238;
                                break;
                            }
                            _22887 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _22888;
                        do
                        {
                            float _18352 = 1.0f - _18127.y;
                            float4 _18363 = mul(float4((float2(_18127.x, _18352) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18127 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18224_dummy_parameter))))), 0)).x, 1.0f), _22887);
                            float _18365 = _18363.w;
                            if (!(_18365 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22888 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18378 = ((_18363.xy / _18365.xx) + 1.0f.xx) * 0.5f;
                            _22888 = float2(_18378.x - _18127.x, _18352 - _18378.y);
                            break;
                        } while(false);
                        float2 _18175 = abs(_22888);
                        if (any(bool2(_18175.x > 100000.0f.xx.x, _18175.y > 100000.0f.xx.y)))
                        {
                            _22889 = false;
                            break;
                        }
                        float _18183 = length(_22888 * _7001);
                        uint _18398_dummy_parameter;
                        bool _18197 = _18183 > ((8.0f * _7001.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _18204;
                        if (_18197)
                        {
                            _18204 = length((r_motion_tp1.Load(int3(int2(floor(_18127 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18398_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7001) < (0.20000000298023223876953125f * _18183);
                        }
                        else
                        {
                            _18204 = _18197;
                        }
                        _22889 = _18204;
                        break;
                    } while(false);
                    if (_22889)
                    {
                        uint _18429_dummy_parameter;
                        _22908 = -(r_motion_tp1.Load(int3(int2(floor(_18127 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18429_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _18456_dummy_parameter;
                    float4x4 _22902;
                    do
                    {
                        bool _22901;
                        do
                        {
                            _18470 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14641)
                            {
                                _22901 = false;
                                break;
                            }
                            uint _18504 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_18504 + 32u) * 4 + 0) != 1u)
                            {
                                _22901 = false;
                                break;
                            }
                            uint _22898;
                            _22898 = 0u;
                            for (; _22898 < 4u; _22898++)
                            {
                                for (uint _22899 = 0u; _22899 < 4u; )
                                {
                                    _18470[_22898][_22899] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18504 + 16u) + (_22898 * 4u)) + _22899) * 4 + 0));
                                    _22899++;
                                    continue;
                                }
                            }
                            _22901 = true;
                            break;
                        } while(false);
                        if (_22901)
                        {
                            _22902 = _18470;
                            break;
                        }
                        _22902 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _22907;
                    do
                    {
                        float _18584 = 1.0f - _18127.y;
                        float4 _18595 = mul(float4((float2(_18127.x, _18584) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18127 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18456_dummy_parameter))))), 0)).x, 1.0f), _22902);
                        float _18597 = _18595.w;
                        if (!(_18597 > 9.9999999747524270787835121154785e-07f))
                        {
                            _22907 = 1000000.0f.xx;
                            break;
                        }
                        float2 _18610 = ((_18595.xy / _18597.xx) + 1.0f.xx) * 0.5f;
                        _22907 = float2(_18610.x - _18127.x, _18584 - _18610.y);
                        break;
                    } while(false);
                    float2 _18142 = abs(_22907);
                    bool2 _18146 = any(bool2(_18142.x > 4.0f.xx.x, _18142.y > 4.0f.xx.y)).xx;
                    _22908 = float2(_18146.x ? 0.0f.xx.x : _22907.x, _18146.y ? 0.0f.xx.y : _22907.y);
                    break;
                } while(false);
                bool _18628 = all(bool2(_22882.x > 0.0f.xx.x, _22882.y > 0.0f.xx.y));
                bool _18634;
                if (_18628)
                {
                    _18634 = all(bool2(_22882.x < 1.0f.xx.x, _22882.y < 1.0f.xx.y));
                }
                else
                {
                    _18634 = _18628;
                }
                float _22924;
                if (_18634)
                {
                    _22924 = length(((_22882 + (_22908 * cbFI_Timestep)) - _5314) * float2(cbFI_RenderSize));
                }
                else
                {
                    _22924 = 1000000000.0f;
                }
                uint _18661_dummy_parameter;
                float _18685 = log(((r_depth_tm1.Load(int3(int2(floor(_18127 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18661_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _16884 = _22924 < 0.3499999940395355224609375f;
                bool _16886 = _21658 < 0.3499999940395355224609375f;
                bool _16896;
                if (_16884)
                {
                    _16896 = (!_16886) || (_18685 > _22949);
                }
                else
                {
                    _16896 = _16884;
                }
                bool _16909;
                if (!_16896)
                {
                    _16909 = ((!_16884) && (!_16886)) && (_22924 < _21658);
                }
                else
                {
                    _16909 = _16896;
                }
                _23597 = _16909 ? _18685 : _22949;
                bool2 _23598 = _16909.xx;
                _23599 = float2(_23598.x ? _22882.x : _21659.x, _23598.y ? _22882.y : _21659.y);
                _23600 = _16909 ? _22924 : _21658;
            }
            float3 _18694 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21628, 0.0f).xyz;
            float3 _18702 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21659, 0.0f).xyz;
            uint _18709_dummy_parameter;
            uint _18740_dummy_parameter;
            float _14522 = exp((_21627 * (-2.0f)) * (_21627 * 2.0f));
            float _14529 = exp((_21658 * (-2.0f)) * (_21658 * 2.0f));
            float _14542 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21659, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18740_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21628, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18709_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
            float _14556 = ((_14522 * cbFI_Timestep) * ((1.0f - _14529) + ((_14529 * 2.0f) * _14542))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
            float _14566 = 1.0f - _14542;
            float _14573 = ((_14529 * _5539) * ((1.0f - _14522) + ((_14522 * 2.0f) * _14566))) + (9.9999997473787516355514526367188e-05f * _5539);
            float _14582 = (((_14522 * _14529) * 4.0f) * _14542) * _14566;
            _22861 = (_14582 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18702 - _18694, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14582)) * max(_14522, _14529));
            _22785 = ((_18694 * _14556) + (_18702 * _14573)) / (_14556 + _14573).xxx;
        }
        else
        {
            _22861 = 1.0f;
            _22785 = _22786;
        }
        uint _7013 = cbFI_pad0 & 255u;
        bool _22630;
        float3 _22784;
        if (_7013 != 0u)
        {
            float3 _7018 = r_present_backbuffer.Load(int3(_4821, 0)).xyz;
            float3 _7022 = r_current_interpolation_source.Load(int3(_4821, 0)).xyz;
            float3 _7026 = abs(_7018 - _7022);
            float3 _21660;
            if (_7013 == 2u)
            {
                _21660 = (abs(_7022) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21660 = 0.000244140625f.xxx;
            }
            bool _7042 = any(bool3(_7026.x > _21660.x, _7026.y > _21660.y, _7026.z > _21660.z));
            bool3 _23601 = _7042.xxx;
            _22784 = float3(_23601.x ? _7018.x : _22785.x, _23601.y ? _7018.y : _22785.y, _23601.z ? _7018.z : _22785.z);
            _22630 = _7042;
        }
        else
        {
            _22784 = _22785;
            _22630 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18778;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18778);
        }
        float3 _22766;
        if (_6687 == 1u)
        {
            _22766 = lerp(_8515, _8523, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22767;
            if (_6687 == 2u)
            {
                _22767 = lerp(_8531, _8539, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22768;
                if (_6687 == 3u)
                {
                    _22768 = float(_22630).xxx;
                }
                else
                {
                    float3 _22769;
                    if (_6687 == 4u)
                    {
                        _22769 = float3(((_19688 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22770;
                        if (_6687 == 5u)
                        {
                            _22770 = float3(((_7810 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22771;
                            if (_6687 == 6u)
                            {
                                _22771 = float3(_21194.xy, _21194.z + _21194.w);
                            }
                            else
                            {
                                float3 _22772;
                                if (_6687 == 7u)
                                {
                                    _22772 = r_current_interpolation_source.Load(int3(_4821, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22773;
                                    if (_6687 == 8u)
                                    {
                                        _22773 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5314, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22774;
                                        if (_6691)
                                        {
                                            uint _18800_dummy_parameter;
                                            uint _18832_dummy_parameter;
                                            _22774 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_5314 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18800_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_5314 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18832_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22775;
                                            if (_6694)
                                            {
                                                _22775 = _8531;
                                            }
                                            else
                                            {
                                                float3 _22776;
                                                if (_6687 == 20u)
                                                {
                                                    _22776 = _8515;
                                                }
                                                else
                                                {
                                                    float3 _22777;
                                                    if (_6687 == 21u)
                                                    {
                                                        _22777 = _8523;
                                                    }
                                                    else
                                                    {
                                                        float3 _22778;
                                                        if (_6687 == 22u)
                                                        {
                                                            _22778 = _8539;
                                                        }
                                                        else
                                                        {
                                                            float3 _22779;
                                                            if (_6687 == 18u)
                                                            {
                                                                _22779 = _22192;
                                                            }
                                                            else
                                                            {
                                                                float3 _22780;
                                                                if (_6687 == 19u)
                                                                {
                                                                    _22780 = _21927;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22781;
                                                                    if (_6687 == 23u)
                                                                    {
                                                                        _22781 = _21668;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22782;
                                                                        if (_6687 == 24u)
                                                                        {
                                                                            uint _7186 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7191 = float(rw_nfru_diagnostics.Load<uint>((_7186 + 35u) * 4 + 0));
                                                                            float _21661;
                                                                            if (_7191 > 0.0f)
                                                                            {
                                                                                _21661 = float(rw_nfru_diagnostics.Load<uint>((_7186 + 34u) * 4 + 0)) / _7191;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21661 = 0.0f;
                                                                            }
                                                                            _22782 = float3(float(rw_nfru_diagnostics.Load<uint>((_7186 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7186 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21661);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22782 = _22784;
                                                                        }
                                                                        _22781 = _22782;
                                                                    }
                                                                    _22780 = _22781;
                                                                }
                                                                _22779 = _22780;
                                                            }
                                                            _22778 = _22779;
                                                        }
                                                        _22777 = _22778;
                                                    }
                                                    _22776 = _22777;
                                                }
                                                _22775 = _22776;
                                            }
                                            _22774 = _22775;
                                        }
                                        _22773 = _22774;
                                    }
                                    _22772 = _22773;
                                }
                                _22771 = _22772;
                            }
                            _22770 = _22771;
                        }
                        _22769 = _22770;
                    }
                    _22768 = _22769;
                }
                _22767 = _22768;
            }
            _22766 = _22767;
        }
        float3 _22765;
        if ((_6687 >= 9u) && (_6687 <= 11u))
        {
            uint _7251 = 64u + uint((_19911.y * cbFI_MvDepthLaneSize.x) + _19911.x);
            uint _7255 = rw_nfru_diagnostics.Load<uint>(_7251 * 4 + 0) & 15u;
            float3 _22799;
            if (_6687 == 10u)
            {
                float3 _22764;
                if ((rw_nfru_diagnostics.Load<uint>(_7251 * 4 + 0) & 32u) != 0u)
                {
                    _22764 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22763;
                    if ((rw_nfru_diagnostics.Load<uint>(_7251 * 4 + 0) & 16u) != 0u)
                    {
                        _22763 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7276 = ((rw_nfru_diagnostics.Load<uint>(_7251 * 4 + 0) & 64u) != 0u).xxx;
                        _22763 = float3(_7276.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7276.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7276.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22764 = _22763;
                }
                _22799 = _22764;
            }
            else
            {
                float3 _22800;
                if (_6687 == 11u)
                {
                    uint _7289 = (rw_nfru_diagnostics.Load<uint>(_7251 * 4 + 0) >> 8u) & 15u;
                    uint _7292 = (rw_nfru_diagnostics.Load<uint>(_7251 * 4 + 0) >> 12u) & 15u;
                    float3 _22756;
                    if ((_7255 == 2u) || (_7255 == 3u))
                    {
                        _22756 = _4520[_7255];
                    }
                    else
                    {
                        bool _7304 = _7289 == 3u;
                        bool _7306 = _7292 == 3u;
                        float3 _22757;
                        if (_7304 && _7306)
                        {
                            _22757 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22758;
                            if (_7304)
                            {
                                _22758 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22759;
                                if (_7306)
                                {
                                    _22759 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22760;
                                    if ((_7289 == 4u) || (_7292 == 4u))
                                    {
                                        _22760 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22761;
                                        if ((_7289 == 1u) || (_7292 == 1u))
                                        {
                                            _22761 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23603 = (_7255 == 1u).xxx;
                                            _22761 = float3(_23603.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23603.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23603.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22760 = _22761;
                                    }
                                    _22759 = _22760;
                                }
                                _22758 = _22759;
                            }
                            _22757 = _22758;
                        }
                        _22756 = _22757;
                    }
                    _22800 = _22756;
                }
                else
                {
                    _22800 = _4520[min(_7255, 7u)];
                }
                _22799 = _22800;
            }
            _22765 = _22799;
        }
        else
        {
            _22765 = _22766;
        }
        float4 _22803;
        if ((_6687 >= 14u) && (_6687 <= 16u))
        {
            float2 _22801;
            if (_6687 == 14u)
            {
                uint _7362_dummy_parameter;
                uint _7368_dummy_parameter;
                _22801 = r_flow_tm1.Load(int3(clamp(int2(floor(_5314 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7362_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7368_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22802;
                if (_6687 == 16u)
                {
                    uint _18908 = r_warped_flow_qdata_tm1.Load(int3(_5330, 0)).x & 2147483647u;
                    uint _18940 = uint(max((int((_18908 >> 16u) & 15u) - 6), 0));
                    _22802 = ((float2(float((1 - (2 * int((_18908 >> 15u) & 1u))) * int(((_18908 >> uint(7)) & 127u) << _18940)), float((1 - (2 * int((_18908 >> 14u) & 1u))) * int((_18908 & 127u) << _18940))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22802 = _7810 * float2(cbFI_DisplaySize);
                }
                _22801 = _22802;
            }
            uint2 _7401 = uint2(clamp(round(_22801 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7403 = _7401.x;
            uint _7410 = _7401.y;
            _22803 = float4(float(_7403 & 255u), float((_7403 >> 8u) | ((_7410 & 15u) << 4u)), float(_7410 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22804;
            if (_6687 == 17u)
            {
                _22804 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5330, 0)).x != 0u), _5774, 0.0f, 1.0f);
            }
            else
            {
                _22804 = float4(_22765, 1.0f);
            }
            _22803 = _22804;
        }
        rw_output[_4821] = _22803.xyz;
        if (_6997)
        {
            uint _18985 = uint((_4821.y * cbFI_DisplaySize.x) + _4821.x) * 2u;
            rw_nfru_select.Store<uint>(_18985 * 4 + 0, spvPackHalf2x16(_22803.xy));
            rw_nfru_select.Store<uint>((_18985 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22803.z, (_22630 || (_6687 != 0u)) ? 2.0f : _22861)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7468 = ((uint(_4821.y) * uint(cbFI_DisplaySize.x)) + uint(_4821.x)) * 6u;
            uint _19011 = spvPackHalf2x16(clamp(_8514.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7468 * 4 + 0, (((_19011 & 32767u) >> 4u) | ((((_19011 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8514.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19046 = spvPackHalf2x16(clamp(_8522.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7468 + 1u) * 4 + 0, (((_19046 & 32767u) >> 4u) | ((((_19046 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8522.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19081 = spvPackHalf2x16(clamp(_8530.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7468 + 2u) * 4 + 0, (((_19081 & 32767u) >> 4u) | ((((_19081 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8530.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19116 = spvPackHalf2x16(clamp(_8538.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7468 + 3u) * 4 + 0, (((_19116 & 32767u) >> 4u) | ((((_19116 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8538.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19143 = r_current_interpolation_source.Load(int3(_4821, 0));
            uint _19157 = spvPackHalf2x16(clamp(_19143.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7468 + 4u) * 4 + 0, (((_19157 & 32767u) >> 4u) | ((((_19157 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19143.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _22880;
            if (_22630 || (_6687 != 0u))
            {
                _22880 = 4294967295u;
            }
            else
            {
                uint _19192 = spvPackHalf2x16(clamp(_22803.xy, 0.0f.xx, 65000.0f.xx));
                _22880 = (((_19192 & 32767u) >> 4u) | ((((_19192 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22803.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7468 + 5u) * 4 + 0, _22880);
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
