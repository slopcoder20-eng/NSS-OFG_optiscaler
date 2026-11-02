static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19657;

static const int2 _1239[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1248[5] = { 2, 4, 7, 11, 16 };
static const float3 _4519[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4820 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4820.x >= cbFI_DisplaySize.x, _4820.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4820] = float4(r_present_backbuffer.Load(int3(_4820, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7663 = cbFI_DisplaySize - int2(1, 1);
                int2 _7664 = clamp(_4820, int2(0, 0), _7663);
                uint _7674 = uint((_7664.y * cbFI_DisplaySize.x) + _7664.x) * 2u;
                uint _7677 = rw_nfru_select.Load<uint>(_7674 * 4 + 0);
                float2 _7678 = spvUnpackHalf2x16(_7677);
                uint _7682 = rw_nfru_select.Load<uint>((_7674 + 1u) * 4 + 0);
                float2 _7683 = spvUnpackHalf2x16(_7682);
                float _7684 = _7678.x;
                float _7686 = _7683.x;
                if (_7683.y > 1.5f)
                {
                    rw_output[_4820] = float4(_7684, _7678.y, _7686, 1.0f).xyz;
                    break;
                }
                int _23087;
                float _23088;
                float3 _23089;
                float _23090;
                float _23091;
                _23091 = 0.0f;
                _23090 = 0.0f;
                _23089 = 0.0f.xxx;
                _23088 = 0.0f;
                _23087 = -2;
                float3 _23094;
                float _23095;
                float _23096;
                float _23097;
                for (; _23087 <= 2; _23091 = _23097, _23090 = _23096, _23089 = _23094, _23088 = _23095, _23087++)
                {
                    _23097 = _23091;
                    _23096 = _23090;
                    _23095 = _23088;
                    _23094 = _23089;
                    for (int _23092 = -2; _23092 <= 2; )
                    {
                        float _7580 = float((_23092 * _23092) + (_23087 * _23087));
                        float _7585 = exp(_7580 * (-0.319999992847442626953125f));
                        int2 _7590 = int2(_23092, _23087);
                        int2 _7700 = clamp(_4820 + (_7590 * int2(2, 2)), int2(0, 0), _7663);
                        uint _7710 = uint((_7700.y * cbFI_DisplaySize.x) + _7700.x) * 2u;
                        float _7607 = exp(_7580 * (-0.5f));
                        int2 _7732 = clamp(_4820 + (_7590 * int2(6, 6)), int2(0, 0), _7663);
                        _23097 += _7607;
                        _23096 += (_7607 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7732.y * cbFI_DisplaySize.x) + _7732.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23095 += _7585;
                        _23094 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7710 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7710 + 1u) * 4 + 0)).x, _19657).xyz * _7585);
                        _23092++;
                        continue;
                    }
                }
                float3 _7637 = _23089 / _23088.xxx;
                rw_output[_4820] = float4(_7637 + ((float4(_7684, _7678.y, _7686, _7683.y).xyz - _7637) * clamp(_23090 / _23091, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5313 = (float2(_4820) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5315 = float2(cbFI_MvDepthLaneSize);
        int2 _5324 = int2(floor(_5313 * _5315));
        int2 _5329 = int2(floor(_5313 * float2(cbFI_FlowLaneSize)));
        float4 _7803 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5313 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7809 = r_warped_filled_flow_tm1.Load(int3(_5329, 0)).xy;
        float2 _7815 = r_warped_filled_motion_tp1.Load(int3(_5324, 0)).xy;
        bool _7837 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19658;
        if (_7837)
        {
            float _7850 = ((2.0f * _5313.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19658 = float2(atan(_7850) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5313.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7850 * _7850))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19658 = _5313;
        }
        bool _5350 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19679;
        bool _19821;
        int2 _19902;
        float3 _22183;
        if (_5350)
        {
            float _19660;
            float _19662;
            _19662 = 2.0f;
            _19660 = -1.0f;
            uint _4912[9];
            float _23098;
            float _23101;
            for (int _19659 = 0; _19659 < 9; _19662 = _23101, _19660 = _23098, _19659++)
            {
                _4912[_19659] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5324 + int2((_19659 % 3) - 1, (_19659 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4912[_19659] != 0u)
                {
                    float _23082;
                    if (_4912[_19659] == 0u)
                    {
                        _23082 = -1.0f;
                    }
                    else
                    {
                        _23082 = float((_4912[_19659] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23101 = min(_19662, _23082);
                    _23098 = max(_19660, _23082);
                }
                else
                {
                    _23101 = _19662;
                    _23098 = _19660;
                }
            }
            float _5396 = float(_19660 >= 0.0f);
            float3 _19225 = 0.0f.xxx;
            _19225.y = _5396;
            float2 _19680;
            bool _19822;
            int2 _19903;
            float3 _22184;
            if ((_19660 - _19662) > 0.0199999995529651641845703125f)
            {
                float _19668;
                int2 _19669;
                float2 _19670;
                int2 _19672;
                float2 _19678;
                _19678 = _7815;
                _19672 = _5324;
                _19670 = _7815;
                _19669 = _5324;
                _19668 = -1.0f;
                float _23106;
                int2 _23110;
                float2 _23121;
                int2 _23132;
                float2 _23165;
                float _23550;
                int _19667 = 0;
                float _23063 = 1000000000.0f;
                for (; _19667 < 9; _23063 = _23550, _19678 = _23165, _19672 = _23132, _19670 = _23121, _19669 = _23110, _19668 = _23106, _19667++)
                {
                    if (_4912[_19667] == 0u)
                    {
                        _23550 = _23063;
                        _23165 = _19678;
                        _23132 = _19672;
                        _23121 = _19670;
                        _23110 = _19669;
                        _23106 = _19668;
                        continue;
                    }
                    int2 _5431 = clamp(_5324 + int2((_19667 % 3) - 1, (_19667 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _7925 = _4912[_19667] & 2147483647u;
                    uint _7957 = uint(max((int((_7925 >> 16u) & 15u) - 6), 0));
                    float2 _5437 = (float2(float((1 - (2 * int((_7925 >> 15u) & 1u))) * int(((_7925 >> uint(7)) & 127u) << _7957)), float((1 - (2 * int((_7925 >> 14u) & 1u))) * int((_7925 & 127u) << _7957))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23049;
                    if (_4912[_19667] == 0u)
                    {
                        _23049 = -1.0f;
                    }
                    else
                    {
                        _23049 = float((_4912[_19667] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5442 = _23049 - 0.100000001490116119384765625f;
                    float2 _23050;
                    if (_7837)
                    {
                        float2 _8034 = clamp((((_19658 + (_5437 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8037 = tan(_8034.x);
                        _23050 = (float2(_8037 / cbFI_DeviceToViewDepth.z, (tan(_8034.y) * sqrt(1.0f + (_8037 * _8037))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23050 = _19658 + (_5437 * cbFI_Timestep);
                    }
                    float _5449 = cbFI_Timestep - 1.0f;
                    float2 _23051;
                    if (_7837)
                    {
                        float2 _8105 = clamp((((_19658 + (_5437 * _5449)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8108 = tan(_8105.x);
                        _23051 = (float2(_8108 / cbFI_DeviceToViewDepth.z, (tan(_8105.y) * sqrt(1.0f + (_8108 * _8108))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23051 = _19658 + (_5437 * _5449);
                    }
                    bool _8141 = all(bool2(_23050.x > 0.0f.xx.x, _23050.y > 0.0f.xx.y));
                    bool _8147;
                    if (_8141)
                    {
                        _8147 = all(bool2(_23050.x < 1.0f.xx.x, _23050.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8147 = _8141;
                    }
                    float _23054;
                    if (_8147)
                    {
                        uint _8154_dummy_parameter;
                        _23054 = max((_5442 - (log((r_depth_tm1.Load(int3(int2(floor(_23050 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8154_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23054 = 0.0f;
                    }
                    bool _8184 = all(bool2(_23051.x > 0.0f.xx.x, _23051.y > 0.0f.xx.y));
                    bool _8190;
                    if (_8184)
                    {
                        _8190 = all(bool2(_23051.x < 1.0f.xx.x, _23051.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8190 = _8184;
                    }
                    float _23055;
                    if (_8190)
                    {
                        uint _8197_dummy_parameter;
                        _23055 = _23054 + max((_5442 - (log((r_depth_tp1.Load(int3(int2(floor(_23051 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8197_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23055 = _23054;
                    }
                    float _23107;
                    int2 _23111;
                    float2 _23122;
                    int2 _23133;
                    float2 _23166;
                    float _23551;
                    if (_23055 == 0.0f)
                    {
                        bool _5484 = _5442 > _19668;
                        bool2 _23559 = _5484.xx;
                        _23551 = _23063;
                        _23166 = float2(_23559.x ? _5437.x : _19678.x, _23559.y ? _5437.y : _19678.y);
                        _23133 = int2(_23559.x ? _5431.x : _19672.x, _23559.y ? _5431.y : _19672.y);
                        _23122 = _19670;
                        _23111 = _19669;
                        _23107 = _5484 ? _5442 : _19668;
                    }
                    else
                    {
                        bool _5493 = _23055 < _23063;
                        bool2 _23555 = _5493.xx;
                        _23551 = _5493 ? _23055 : _23063;
                        _23166 = _19678;
                        _23133 = _19672;
                        _23122 = float2(_23555.x ? _5437.x : _19670.x, _23555.y ? _5437.y : _19670.y);
                        _23111 = int2(_23555.x ? _5431.x : _19669.x, _23555.y ? _5431.y : _19669.y);
                        _23107 = _19668;
                    }
                    _23550 = _23551;
                    _23165 = _23166;
                    _23132 = _23133;
                    _23121 = _23122;
                    _23110 = _23111;
                    _23106 = _23107;
                }
                bool _5505 = _19668 < 0.0f;
                bool2 _23565 = _5505.xx;
                int2 _23568 = int2(_23565.x ? _19669.x : _19672.x, _23565.y ? _19669.y : _19672.y);
                _22184 = float3(1.0f, _5396, float(any(bool2(_23568.x != _5324.x, _23568.y != _5324.y))));
                _19903 = _23568;
                _19822 = _5505 ? false : true;
                _19680 = float2(_23565.x ? _19670.x : _19678.x, _23565.y ? _19670.y : _19678.y);
            }
            else
            {
                _22184 = _19225;
                _19903 = _5324;
                _19822 = false;
                _19680 = _7815;
            }
            _22183 = _22184;
            _19902 = _19903;
            _19821 = _19822;
            _19679 = _19680;
        }
        else
        {
            _22183 = 0.0f.xxx;
            _19902 = _5324;
            _19821 = false;
            _19679 = _7815;
        }
        float2 _19681;
        if (_7837)
        {
            float2 _8262 = clamp((((_19658 + (_19679 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8265 = tan(_8262.x);
            _19681 = (float2(_8265 / cbFI_DeviceToViewDepth.z, (tan(_8262.y) * sqrt(1.0f + (_8265 * _8265))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19681 = _19658 + (_19679 * cbFI_Timestep);
        }
        float _5528 = cbFI_Timestep - 1.0f;
        float2 _19683;
        if (_7837)
        {
            float2 _8333 = clamp((((_19658 + (_19679 * _5528)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8336 = tan(_8333.x);
            _19683 = (float2(_8336 / cbFI_DeviceToViewDepth.z, (tan(_8333.y) * sqrt(1.0f + (_8336 * _8336))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19683 = _19658 + (_19679 * _5528);
        }
        float _5533 = -cbFI_Timestep;
        float2 _19684;
        if (_7837)
        {
            float2 _8404 = clamp((((_19658 + (_7809 * _5533)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8407 = tan(_8404.x);
            _19684 = (float2(_8407 / cbFI_DeviceToViewDepth.z, (tan(_8404.y) * sqrt(1.0f + (_8407 * _8407))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19684 = _19658 + (_7809 * _5533);
        }
        float _5538 = 1.0f - cbFI_Timestep;
        float2 _19685;
        if (_7837)
        {
            float2 _8475 = clamp((((_19658 + (_7809 * _5538)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8478 = tan(_8475.x);
            _19685 = (float2(_8478 / cbFI_DeviceToViewDepth.z, (tan(_8475.y) * sqrt(1.0f + (_8478 * _8478))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19685 = _19658 + (_7809 * _5538);
        }
        float4 _8513 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19681, 0.0f);
        float3 _8514 = _8513.xyz;
        float4 _8521 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19683, 0.0f);
        float3 _8522 = _8521.xyz;
        float4 _8529 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19684, 0.0f);
        float3 _8530 = _8529.xyz;
        float4 _8537 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19685, 0.0f);
        float3 _8538 = _8537.xyz;
        float4 _8552 = exp(_7803 - max(max(max(_7803.x, _7803.y), _7803.z), _7803.w).xxxx);
        float4 _8559 = _8552 / (dot(_8552, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5554 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19892;
        float _21200;
        if (_5554)
        {
            float2 _5560 = 0.5f.xx / _5315;
            float _5563 = _5560.x;
            float _5564 = -_5563;
            float _5566 = _5560.y;
            float _5567 = -_5566;
            float2 _5569 = _5313 + float2(_5564, _5567);
            float2 _5571 = float2(cbFI_DisplaySize);
            bool _19702;
            do
            {
                bool _8639 = all(bool2(_5569.x > 0.0f.xx.x, _5569.y > 0.0f.xx.y));
                bool _8645;
                if (_8639)
                {
                    _8645 = all(bool2(_5569.x < 1.0f.xx.x, _5569.y < 1.0f.xx.y));
                }
                else
                {
                    _8645 = _8639;
                }
                if (!_8645)
                {
                    _19702 = false;
                    break;
                }
                uint _8652_dummy_parameter;
                float4x4 _19700;
                do
                {
                    float4x4 _8666;
                    bool _19699;
                    do
                    {
                        _8666 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19699 = false;
                            break;
                        }
                        uint _8700 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8700 + 32u) * 4 + 0) != 1u)
                        {
                            _19699 = false;
                            break;
                        }
                        uint _19696;
                        _19696 = 0u;
                        for (; _19696 < 4u; _19696++)
                        {
                            for (uint _19697 = 0u; _19697 < 4u; )
                            {
                                _8666[_19696][_19697] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8700 + (_19696 * 4u)) + _19697) * 4 + 0));
                                _19697++;
                                continue;
                            }
                        }
                        _19699 = true;
                        break;
                    } while(false);
                    if (_19699)
                    {
                        _19700 = _8666;
                        break;
                    }
                    _19700 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19701;
                do
                {
                    float _8777 = _5569.x;
                    float _8780 = 1.0f - _5569.y;
                    float4 _8791 = mul(float4((float2(_8777, _8780) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5569 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8652_dummy_parameter))))), 0)).x, 1.0f), _19700);
                    float _8793 = _8791.w;
                    if (!(_8793 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19701 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8806 = ((_8791.xy / _8793.xx) + 1.0f.xx) * 0.5f;
                    _19701 = float2(_8806.x - _8777, _8780 - _8806.y);
                    break;
                } while(false);
                float2 _8603 = abs(_19701);
                if (any(bool2(_8603.x > 100000.0f.xx.x, _8603.y > 100000.0f.xx.y)))
                {
                    _19702 = false;
                    break;
                }
                float _8611 = length(_19701 * _5571);
                uint _8826_dummy_parameter;
                bool _8625 = _8611 > ((8.0f * _5571.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8632;
                if (_8625)
                {
                    _8632 = length((r_motion_tp1.Load(int3(int2(floor(_5569 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8826_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5571) < (0.20000000298023223876953125f * _8611);
                }
                else
                {
                    _8632 = _8625;
                }
                _19702 = _8632;
                break;
            } while(false);
            float2 _5581 = _5313 + float2(_5563, _5567);
            bool _19709;
            do
            {
                bool _8912 = all(bool2(_5581.x > 0.0f.xx.x, _5581.y > 0.0f.xx.y));
                bool _8918;
                if (_8912)
                {
                    _8918 = all(bool2(_5581.x < 1.0f.xx.x, _5581.y < 1.0f.xx.y));
                }
                else
                {
                    _8918 = _8912;
                }
                if (!_8918)
                {
                    _19709 = false;
                    break;
                }
                uint _8925_dummy_parameter;
                float4x4 _19707;
                do
                {
                    float4x4 _8939;
                    bool _19706;
                    do
                    {
                        _8939 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19706 = false;
                            break;
                        }
                        uint _8973 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8973 + 32u) * 4 + 0) != 1u)
                        {
                            _19706 = false;
                            break;
                        }
                        uint _19703;
                        _19703 = 0u;
                        for (; _19703 < 4u; _19703++)
                        {
                            for (uint _19704 = 0u; _19704 < 4u; )
                            {
                                _8939[_19703][_19704] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8973 + (_19703 * 4u)) + _19704) * 4 + 0));
                                _19704++;
                                continue;
                            }
                        }
                        _19706 = true;
                        break;
                    } while(false);
                    if (_19706)
                    {
                        _19707 = _8939;
                        break;
                    }
                    _19707 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19708;
                do
                {
                    float _9050 = _5581.x;
                    float _9053 = 1.0f - _5581.y;
                    float4 _9064 = mul(float4((float2(_9050, _9053) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5581 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8925_dummy_parameter))))), 0)).x, 1.0f), _19707);
                    float _9066 = _9064.w;
                    if (!(_9066 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19708 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9079 = ((_9064.xy / _9066.xx) + 1.0f.xx) * 0.5f;
                    _19708 = float2(_9079.x - _9050, _9053 - _9079.y);
                    break;
                } while(false);
                float2 _8876 = abs(_19708);
                if (any(bool2(_8876.x > 100000.0f.xx.x, _8876.y > 100000.0f.xx.y)))
                {
                    _19709 = false;
                    break;
                }
                float _8884 = length(_19708 * _5571);
                uint _9099_dummy_parameter;
                bool _8898 = _8884 > ((8.0f * _5571.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8905;
                if (_8898)
                {
                    _8905 = length((r_motion_tp1.Load(int3(int2(floor(_5581 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9099_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5571) < (0.20000000298023223876953125f * _8884);
                }
                else
                {
                    _8905 = _8898;
                }
                _19709 = _8905;
                break;
            } while(false);
            float2 _5594 = _5313 + float2(_5564, _5566);
            bool _19716;
            do
            {
                bool _9185 = all(bool2(_5594.x > 0.0f.xx.x, _5594.y > 0.0f.xx.y));
                bool _9191;
                if (_9185)
                {
                    _9191 = all(bool2(_5594.x < 1.0f.xx.x, _5594.y < 1.0f.xx.y));
                }
                else
                {
                    _9191 = _9185;
                }
                if (!_9191)
                {
                    _19716 = false;
                    break;
                }
                uint _9198_dummy_parameter;
                float4x4 _19714;
                do
                {
                    float4x4 _9212;
                    bool _19713;
                    do
                    {
                        _9212 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19713 = false;
                            break;
                        }
                        uint _9246 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9246 + 32u) * 4 + 0) != 1u)
                        {
                            _19713 = false;
                            break;
                        }
                        uint _19710;
                        _19710 = 0u;
                        for (; _19710 < 4u; _19710++)
                        {
                            for (uint _19711 = 0u; _19711 < 4u; )
                            {
                                _9212[_19710][_19711] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9246 + (_19710 * 4u)) + _19711) * 4 + 0));
                                _19711++;
                                continue;
                            }
                        }
                        _19713 = true;
                        break;
                    } while(false);
                    if (_19713)
                    {
                        _19714 = _9212;
                        break;
                    }
                    _19714 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19715;
                do
                {
                    float _9323 = _5594.x;
                    float _9326 = 1.0f - _5594.y;
                    float4 _9337 = mul(float4((float2(_9323, _9326) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5594 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9198_dummy_parameter))))), 0)).x, 1.0f), _19714);
                    float _9339 = _9337.w;
                    if (!(_9339 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19715 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9352 = ((_9337.xy / _9339.xx) + 1.0f.xx) * 0.5f;
                    _19715 = float2(_9352.x - _9323, _9326 - _9352.y);
                    break;
                } while(false);
                float2 _9149 = abs(_19715);
                if (any(bool2(_9149.x > 100000.0f.xx.x, _9149.y > 100000.0f.xx.y)))
                {
                    _19716 = false;
                    break;
                }
                float _9157 = length(_19715 * _5571);
                uint _9372_dummy_parameter;
                bool _9171 = _9157 > ((8.0f * _5571.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9178;
                if (_9171)
                {
                    _9178 = length((r_motion_tp1.Load(int3(int2(floor(_5594 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9372_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5571) < (0.20000000298023223876953125f * _9157);
                }
                else
                {
                    _9178 = _9171;
                }
                _19716 = _9178;
                break;
            } while(false);
            float2 _5606 = _5313 + _5560;
            bool _19723;
            do
            {
                bool _9458 = all(bool2(_5606.x > 0.0f.xx.x, _5606.y > 0.0f.xx.y));
                bool _9464;
                if (_9458)
                {
                    _9464 = all(bool2(_5606.x < 1.0f.xx.x, _5606.y < 1.0f.xx.y));
                }
                else
                {
                    _9464 = _9458;
                }
                if (!_9464)
                {
                    _19723 = false;
                    break;
                }
                uint _9471_dummy_parameter;
                float4x4 _19721;
                do
                {
                    float4x4 _9485;
                    bool _19720;
                    do
                    {
                        _9485 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19720 = false;
                            break;
                        }
                        uint _9519 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9519 + 32u) * 4 + 0) != 1u)
                        {
                            _19720 = false;
                            break;
                        }
                        uint _19717;
                        _19717 = 0u;
                        for (; _19717 < 4u; _19717++)
                        {
                            for (uint _19718 = 0u; _19718 < 4u; )
                            {
                                _9485[_19717][_19718] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9519 + (_19717 * 4u)) + _19718) * 4 + 0));
                                _19718++;
                                continue;
                            }
                        }
                        _19720 = true;
                        break;
                    } while(false);
                    if (_19720)
                    {
                        _19721 = _9485;
                        break;
                    }
                    _19721 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19722;
                do
                {
                    float _9596 = _5606.x;
                    float _9599 = 1.0f - _5606.y;
                    float4 _9610 = mul(float4((float2(_9596, _9599) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5606 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9471_dummy_parameter))))), 0)).x, 1.0f), _19721);
                    float _9612 = _9610.w;
                    if (!(_9612 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19722 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9625 = ((_9610.xy / _9612.xx) + 1.0f.xx) * 0.5f;
                    _19722 = float2(_9625.x - _9596, _9599 - _9625.y);
                    break;
                } while(false);
                float2 _9422 = abs(_19722);
                if (any(bool2(_9422.x > 100000.0f.xx.x, _9422.y > 100000.0f.xx.y)))
                {
                    _19723 = false;
                    break;
                }
                float _9430 = length(_19722 * _5571);
                uint _9645_dummy_parameter;
                bool _9444 = _9430 > ((8.0f * _5571.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9451;
                if (_9444)
                {
                    _9451 = length((r_motion_tp1.Load(int3(int2(floor(_5606 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9645_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5571) < (0.20000000298023223876953125f * _9430);
                }
                else
                {
                    _9451 = _9444;
                }
                _19723 = _9451;
                break;
            } while(false);
            float _5612 = 0.25f * (((float(_19702) + float(_19709)) + float(_19716)) + float(_19723));
            float4 _19893;
            if (_5612 < 1.0f)
            {
                bool _19730;
                do
                {
                    bool _9731 = all(bool2(_19681.x > 0.0f.xx.x, _19681.y > 0.0f.xx.y));
                    bool _9737;
                    if (_9731)
                    {
                        _9737 = all(bool2(_19681.x < 1.0f.xx.x, _19681.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9737 = _9731;
                    }
                    if (!_9737)
                    {
                        _19730 = false;
                        break;
                    }
                    uint _9744_dummy_parameter;
                    float4x4 _19728;
                    do
                    {
                        float4x4 _9758;
                        bool _19727;
                        do
                        {
                            _9758 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19727 = false;
                                break;
                            }
                            uint _9792 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9792 + 32u) * 4 + 0) != 1u)
                            {
                                _19727 = false;
                                break;
                            }
                            uint _19724;
                            _19724 = 0u;
                            for (; _19724 < 4u; _19724++)
                            {
                                for (uint _19725 = 0u; _19725 < 4u; )
                                {
                                    _9758[_19724][_19725] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9792 + (_19724 * 4u)) + _19725) * 4 + 0));
                                    _19725++;
                                    continue;
                                }
                            }
                            _19727 = true;
                            break;
                        } while(false);
                        if (_19727)
                        {
                            _19728 = _9758;
                            break;
                        }
                        _19728 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19729;
                    do
                    {
                        float _9872 = 1.0f - _19681.y;
                        float4 _9883 = mul(float4((float2(_19681.x, _9872) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19681 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9744_dummy_parameter))))), 0)).x, 1.0f), _19728);
                        float _9885 = _9883.w;
                        if (!(_9885 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19729 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9898 = ((_9883.xy / _9885.xx) + 1.0f.xx) * 0.5f;
                        _19729 = float2(_9898.x - _19681.x, _9872 - _9898.y);
                        break;
                    } while(false);
                    float2 _9695 = abs(_19729);
                    if (any(bool2(_9695.x > 100000.0f.xx.x, _9695.y > 100000.0f.xx.y)))
                    {
                        _19730 = false;
                        break;
                    }
                    float _9703 = length(_19729 * _5571);
                    uint _9918_dummy_parameter;
                    bool _9717 = _9703 > ((8.0f * _5571.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9724;
                    if (_9717)
                    {
                        _9724 = length((r_motion_tp1.Load(int3(int2(floor(_19681 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9918_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5571) < (0.20000000298023223876953125f * _9703);
                    }
                    else
                    {
                        _9724 = _9717;
                    }
                    _19730 = _9724;
                    break;
                } while(false);
                bool _19737;
                do
                {
                    bool _10004 = all(bool2(_19683.x > 0.0f.xx.x, _19683.y > 0.0f.xx.y));
                    bool _10010;
                    if (_10004)
                    {
                        _10010 = all(bool2(_19683.x < 1.0f.xx.x, _19683.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10010 = _10004;
                    }
                    if (!_10010)
                    {
                        _19737 = false;
                        break;
                    }
                    uint _10017_dummy_parameter;
                    float4x4 _19735;
                    do
                    {
                        float4x4 _10031;
                        bool _19734;
                        do
                        {
                            _10031 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19734 = false;
                                break;
                            }
                            uint _10065 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10065 + 32u) * 4 + 0) != 1u)
                            {
                                _19734 = false;
                                break;
                            }
                            uint _19731;
                            _19731 = 0u;
                            for (; _19731 < 4u; _19731++)
                            {
                                for (uint _19732 = 0u; _19732 < 4u; )
                                {
                                    _10031[_19731][_19732] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10065 + (_19731 * 4u)) + _19732) * 4 + 0));
                                    _19732++;
                                    continue;
                                }
                            }
                            _19734 = true;
                            break;
                        } while(false);
                        if (_19734)
                        {
                            _19735 = _10031;
                            break;
                        }
                        _19735 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19736;
                    do
                    {
                        float _10145 = 1.0f - _19683.y;
                        float4 _10156 = mul(float4((float2(_19683.x, _10145) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19683 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10017_dummy_parameter))))), 0)).x, 1.0f), _19735);
                        float _10158 = _10156.w;
                        if (!(_10158 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19736 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10171 = ((_10156.xy / _10158.xx) + 1.0f.xx) * 0.5f;
                        _19736 = float2(_10171.x - _19683.x, _10145 - _10171.y);
                        break;
                    } while(false);
                    float2 _9968 = abs(_19736);
                    if (any(bool2(_9968.x > 100000.0f.xx.x, _9968.y > 100000.0f.xx.y)))
                    {
                        _19737 = false;
                        break;
                    }
                    float _9976 = length(_19736 * _5571);
                    uint _10191_dummy_parameter;
                    bool _9990 = _9976 > ((8.0f * _5571.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9997;
                    if (_9990)
                    {
                        _9997 = length((r_motion_tp1.Load(int3(int2(floor(_19683 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10191_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5571) < (0.20000000298023223876953125f * _9976);
                    }
                    else
                    {
                        _9997 = _9990;
                    }
                    _19737 = _9997;
                    break;
                } while(false);
                bool _19744;
                do
                {
                    bool _10277 = all(bool2(_19684.x > 0.0f.xx.x, _19684.y > 0.0f.xx.y));
                    bool _10283;
                    if (_10277)
                    {
                        _10283 = all(bool2(_19684.x < 1.0f.xx.x, _19684.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10283 = _10277;
                    }
                    if (!_10283)
                    {
                        _19744 = false;
                        break;
                    }
                    uint _10290_dummy_parameter;
                    float4x4 _19742;
                    do
                    {
                        float4x4 _10304;
                        bool _19741;
                        do
                        {
                            _10304 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19741 = false;
                                break;
                            }
                            uint _10338 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10338 + 32u) * 4 + 0) != 1u)
                            {
                                _19741 = false;
                                break;
                            }
                            uint _19738;
                            _19738 = 0u;
                            for (; _19738 < 4u; _19738++)
                            {
                                for (uint _19739 = 0u; _19739 < 4u; )
                                {
                                    _10304[_19738][_19739] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10338 + (_19738 * 4u)) + _19739) * 4 + 0));
                                    _19739++;
                                    continue;
                                }
                            }
                            _19741 = true;
                            break;
                        } while(false);
                        if (_19741)
                        {
                            _19742 = _10304;
                            break;
                        }
                        _19742 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19743;
                    do
                    {
                        float _10418 = 1.0f - _19684.y;
                        float4 _10429 = mul(float4((float2(_19684.x, _10418) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19684 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10290_dummy_parameter))))), 0)).x, 1.0f), _19742);
                        float _10431 = _10429.w;
                        if (!(_10431 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19743 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10444 = ((_10429.xy / _10431.xx) + 1.0f.xx) * 0.5f;
                        _19743 = float2(_10444.x - _19684.x, _10418 - _10444.y);
                        break;
                    } while(false);
                    float2 _10241 = abs(_19743);
                    if (any(bool2(_10241.x > 100000.0f.xx.x, _10241.y > 100000.0f.xx.y)))
                    {
                        _19744 = false;
                        break;
                    }
                    float _10249 = length(_19743 * _5571);
                    uint _10464_dummy_parameter;
                    bool _10263 = _10249 > ((8.0f * _5571.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10270;
                    if (_10263)
                    {
                        _10270 = length((r_motion_tp1.Load(int3(int2(floor(_19684 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10464_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5571) < (0.20000000298023223876953125f * _10249);
                    }
                    else
                    {
                        _10270 = _10263;
                    }
                    _19744 = _10270;
                    break;
                } while(false);
                bool _19751;
                do
                {
                    bool _10550 = all(bool2(_19685.x > 0.0f.xx.x, _19685.y > 0.0f.xx.y));
                    bool _10556;
                    if (_10550)
                    {
                        _10556 = all(bool2(_19685.x < 1.0f.xx.x, _19685.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10556 = _10550;
                    }
                    if (!_10556)
                    {
                        _19751 = false;
                        break;
                    }
                    uint _10563_dummy_parameter;
                    float4x4 _19749;
                    do
                    {
                        float4x4 _10577;
                        bool _19748;
                        do
                        {
                            _10577 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19748 = false;
                                break;
                            }
                            uint _10611 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10611 + 32u) * 4 + 0) != 1u)
                            {
                                _19748 = false;
                                break;
                            }
                            uint _19745;
                            _19745 = 0u;
                            for (; _19745 < 4u; _19745++)
                            {
                                for (uint _19746 = 0u; _19746 < 4u; )
                                {
                                    _10577[_19745][_19746] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10611 + (_19745 * 4u)) + _19746) * 4 + 0));
                                    _19746++;
                                    continue;
                                }
                            }
                            _19748 = true;
                            break;
                        } while(false);
                        if (_19748)
                        {
                            _19749 = _10577;
                            break;
                        }
                        _19749 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19750;
                    do
                    {
                        float _10691 = 1.0f - _19685.y;
                        float4 _10702 = mul(float4((float2(_19685.x, _10691) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19685 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10563_dummy_parameter))))), 0)).x, 1.0f), _19749);
                        float _10704 = _10702.w;
                        if (!(_10704 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19750 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10717 = ((_10702.xy / _10704.xx) + 1.0f.xx) * 0.5f;
                        _19750 = float2(_10717.x - _19685.x, _10691 - _10717.y);
                        break;
                    } while(false);
                    float2 _10514 = abs(_19750);
                    if (any(bool2(_10514.x > 100000.0f.xx.x, _10514.y > 100000.0f.xx.y)))
                    {
                        _19751 = false;
                        break;
                    }
                    float _10522 = length(_19750 * _5571);
                    uint _10737_dummy_parameter;
                    bool _10536 = _10522 > ((8.0f * _5571.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10543;
                    if (_10536)
                    {
                        _10543 = length((r_motion_tp1.Load(int3(int2(floor(_19685 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10737_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5571) < (0.20000000298023223876953125f * _10522);
                    }
                    else
                    {
                        _10543 = _10536;
                    }
                    _19751 = _10543;
                    break;
                } while(false);
                float4 _5639 = _8559 * float4(_19730 ? 0.0f : 1.0f, _19737 ? 0.0f : 1.0f, _19744 ? 0.0f : 1.0f, _19751 ? 0.0f : 1.0f);
                float _5641 = dot(_5639, 1.0f.xxxx);
                float4 _19894;
                if (_5641 > 0.001000000047497451305389404296875f)
                {
                    _19894 = _5639 / _5641.xxxx;
                }
                else
                {
                    _19894 = _8559;
                }
                _19893 = _19894;
            }
            else
            {
                _19893 = _8559;
            }
            _21200 = _5612;
            _19892 = _19893;
        }
        else
        {
            _21200 = 0.0f;
            _19892 = _8559;
        }
        bool _5658 = _5350 && (!_19821);
        bool _5667;
        if (_5658)
        {
            _5667 = (_19892.z + _19892.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5667 = _5658;
        }
        bool _5678;
        if (_5667)
        {
            _5678 = length((_19684 - _19681) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5678 = _5667;
        }
        bool _19981;
        if (_5678)
        {
            uint4 _10766 = r_warped_motion_qdata_tp1.Load(int3(_19902, 0));
            uint _10767 = _10766.x;
            bool _19984;
            if (_10767 != 0u)
            {
                float _19970;
                if (_10767 == 0u)
                {
                    _19970 = -1.0f;
                }
                else
                {
                    _19970 = float((_10767 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5688 = _19970 - 0.12000000476837158203125f;
                bool _10786 = all(bool2(_19684.x > 0.0f.xx.x, _19684.y > 0.0f.xx.y));
                bool _10792;
                if (_10786)
                {
                    _10792 = all(bool2(_19684.x < 1.0f.xx.x, _19684.y < 1.0f.xx.y));
                }
                else
                {
                    _10792 = _10786;
                }
                bool _5698;
                if (_10792)
                {
                    uint _10799_dummy_parameter;
                    _5698 = (log((r_depth_tm1.Load(int3(int2(floor(_19684 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10799_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5688;
                }
                else
                {
                    _5698 = _10792;
                }
                bool _5712;
                if (!_5698)
                {
                    bool _10829 = all(bool2(_19685.x > 0.0f.xx.x, _19685.y > 0.0f.xx.y));
                    bool _10835;
                    if (_10829)
                    {
                        _10835 = all(bool2(_19685.x < 1.0f.xx.x, _19685.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10835 = _10829;
                    }
                    bool _5710;
                    if (_10835)
                    {
                        uint _10842_dummy_parameter;
                        _5710 = (log((r_depth_tp1.Load(int3(int2(floor(_19685 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10842_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5688;
                    }
                    else
                    {
                        _5710 = _10835;
                    }
                    _5712 = _5710;
                }
                else
                {
                    _5712 = _5698;
                }
                _19984 = _5712;
            }
            else
            {
                _19984 = false;
            }
            _19981 = _19984;
        }
        else
        {
            _19981 = false;
        }
        bool _5717 = _19821 || _19981;
        bool _5722;
        if (_5717)
        {
            bool _10872 = all(bool2(_19681.x > 0.0f.xx.x, _19681.y > 0.0f.xx.y));
            bool _10878;
            if (_10872)
            {
                _10878 = all(bool2(_19681.x < 1.0f.xx.x, _19681.y < 1.0f.xx.y));
            }
            else
            {
                _10878 = _10872;
            }
            _5722 = _10878;
        }
        else
        {
            _5722 = _5717;
        }
        bool _5727;
        if (_5722)
        {
            bool _10883 = all(bool2(_19683.x > 0.0f.xx.x, _19683.y > 0.0f.xx.y));
            bool _10889;
            if (_10883)
            {
                _10889 = all(bool2(_19683.x < 1.0f.xx.x, _19683.y < 1.0f.xx.y));
            }
            else
            {
                _10889 = _10883;
            }
            _5727 = _10889;
        }
        else
        {
            _5727 = _5722;
        }
        float4 _20104;
        if (_5727)
        {
            float _5733 = _19892.x + _19892.y;
            float _5738 = _19892.z + _19892.w;
            float _19999;
            if (_5733 > 0.001000000047497451305389404296875f)
            {
                _19999 = _19892.x / _5733;
            }
            else
            {
                _19999 = _5538;
            }
            _20104 = float4(_19892.x + (_5738 * _19999), _19892.y + (_5738 * (1.0f - _19999)), 0.0f, 0.0f);
        }
        else
        {
            _20104 = _19892;
        }
        bool _10917 = (cbFI_pad0 & 1024u) != 0u;
        bool _10893 = !_10917;
        bool _10894 = !_10893;
        bool _10911;
        if (_10894)
        {
            _10911 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19902.y * cbFI_MvDepthLaneSize.x) + _19902.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _10911 = _10893;
        }
        bool _10943;
        if (_10894)
        {
            _10943 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5329.y * cbFI_FlowLaneSize.x) + _5329.x)) * 4 + 0) != 0u;
        }
        else
        {
            _10943 = _10893;
        }
        float _5773 = float(_10943);
        bool _20125;
        float4 _20164;
        float3 _21918;
        if (_10917)
        {
            bool _5783;
            if (_10911)
            {
                _5783 = all(bool2(_19681.x > 0.0f.xx.x, _19681.y > 0.0f.xx.y));
            }
            else
            {
                _5783 = _10911;
            }
            bool _5789;
            if (_5783)
            {
                _5789 = all(bool2(_19681.x < 1.0f.xx.x, _19681.y < 1.0f.xx.y));
            }
            else
            {
                _5789 = _5783;
            }
            bool _5796;
            if (_10911)
            {
                _5796 = all(bool2(_19683.x > 0.0f.xx.x, _19683.y > 0.0f.xx.y));
            }
            else
            {
                _5796 = _10911;
            }
            bool _5802;
            if (_5796)
            {
                _5802 = all(bool2(_19683.x < 1.0f.xx.x, _19683.y < 1.0f.xx.y));
            }
            else
            {
                _5802 = _5796;
            }
            bool _5809;
            if (_10943)
            {
                _5809 = all(bool2(_19684.x > 0.0f.xx.x, _19684.y > 0.0f.xx.y));
            }
            else
            {
                _5809 = _10943;
            }
            bool _5815;
            if (_5809)
            {
                _5815 = all(bool2(_19684.x < 1.0f.xx.x, _19684.y < 1.0f.xx.y));
            }
            else
            {
                _5815 = _5809;
            }
            bool _5822;
            if (_10943)
            {
                _5822 = all(bool2(_19685.x > 0.0f.xx.x, _19685.y > 0.0f.xx.y));
            }
            else
            {
                _5822 = _10943;
            }
            bool _5828;
            if (_5822)
            {
                _5828 = all(bool2(_19685.x < 1.0f.xx.x, _19685.y < 1.0f.xx.y));
            }
            else
            {
                _5828 = _5822;
            }
            bool _5830 = !_10911;
            if (_5830)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10985;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _10985);
                }
            }
            bool _5835 = !_10943;
            if (_5835)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _10995;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _10995);
                }
            }
            if (_10911 && _5835)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11005;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11005);
                }
            }
            if (_5830 && _10943)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11015;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11015);
                }
            }
            float _5854 = float(_5789);
            float _5856 = float(_5802);
            bool _5859 = _5815 && _5828;
            float _20033;
            if (_5859)
            {
                _20033 = 1.0f;
            }
            else
            {
                _20033 = (_5815 || _5828) ? 0.5f : 0.0f;
            }
            bool _20048;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5789)) && (!_5802))
            {
                bool _5889;
                if (_5859)
                {
                    float _20041;
                    do
                    {
                        bool _11099 = all(bool2(_19684.x > 0.0f.xx.x, _19684.y > 0.0f.xx.y));
                        bool _11105;
                        if (_11099)
                        {
                            _11105 = all(bool2(_19684.x < 1.0f.xx.x, _19684.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11105 = _11099;
                        }
                        bool _11036 = !_11105;
                        bool _11043;
                        if (!_11036)
                        {
                            bool _11110 = all(bool2(_19685.x > 0.0f.xx.x, _19685.y > 0.0f.xx.y));
                            bool _11116;
                            if (_11110)
                            {
                                _11116 = all(bool2(_19685.x < 1.0f.xx.x, _19685.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11116 = _11110;
                            }
                            _11043 = !_11116;
                        }
                        else
                        {
                            _11043 = _11036;
                        }
                        if (_11043)
                        {
                            _20041 = 0.0f;
                            break;
                        }
                        uint _11123_dummy_parameter;
                        uint _11139_dummy_parameter;
                        float4x4 _20040;
                        do
                        {
                            float4x4 _11153;
                            bool _20039;
                            do
                            {
                                _11153 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20039 = false;
                                    break;
                                }
                                uint _11187 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11187 + 32u) * 4 + 0) != 1u)
                                {
                                    _20039 = false;
                                    break;
                                }
                                uint _20036;
                                _20036 = 0u;
                                for (; _20036 < 4u; _20036++)
                                {
                                    for (uint _20037 = 0u; _20037 < 4u; )
                                    {
                                        _11153[_20036][_20037] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11187 + 16u) + (_20036 * 4u)) + _20037) * 4 + 0));
                                        _20037++;
                                        continue;
                                    }
                                }
                                _20039 = true;
                                break;
                            } while(false);
                            if (_20039)
                            {
                                _20040 = _11153;
                                break;
                            }
                            _20040 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11064 = mul(float4((float2(_19684.x, 1.0f - _19684.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19684 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11123_dummy_parameter))))), 0)).x, 1.0f), _20040);
                        float _11066 = _11064.w;
                        if (abs(_11066) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20041 = 0.0f;
                            break;
                        }
                        float _11077 = abs(cbFI_DeviceToViewDepth.y / ((_11064.z / _11066) - cbFI_DeviceToViewDepth.x));
                        float _11080 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19685 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11139_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20041 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11077 - _11080) / max(max(_11077, _11080), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5889 = _20041 >= 0.5f;
                }
                else
                {
                    _5889 = _5859;
                }
                bool _5897;
                if (_5889)
                {
                    _5897 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5897 = _5889;
                }
                bool _20049;
                if (_5897)
                {
                    uint _11291_dummy_parameter;
                    float4x4 _20046;
                    do
                    {
                        float4x4 _11305;
                        bool _20045;
                        do
                        {
                            _11305 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20045 = false;
                                break;
                            }
                            uint _11339 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11339 + 32u) * 4 + 0) != 1u)
                            {
                                _20045 = false;
                                break;
                            }
                            uint _20042;
                            _20042 = 0u;
                            for (; _20042 < 4u; _20042++)
                            {
                                for (uint _20043 = 0u; _20043 < 4u; )
                                {
                                    _11305[_20042][_20043] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11339 + 16u) + (_20042 * 4u)) + _20043) * 4 + 0));
                                    _20043++;
                                    continue;
                                }
                            }
                            _20045 = true;
                            break;
                        } while(false);
                        if (_20045)
                        {
                            _20046 = _11305;
                            break;
                        }
                        _20046 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20047;
                    do
                    {
                        float _11419 = 1.0f - _19684.y;
                        float4 _11430 = mul(float4((float2(_19684.x, _11419) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19684 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11291_dummy_parameter))))), 0)).x, 1.0f), _20046);
                        float _11432 = _11430.w;
                        if (!(_11432 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20047 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11445 = ((_11430.xy / _11432.xx) + 1.0f.xx) * 0.5f;
                        _20047 = float2(_11445.x - _19684.x, _11419 - _11445.y);
                        break;
                    } while(false);
                    float2 _5910 = float2(cbFI_DisplaySize);
                    _20049 = length(((_19684 + _20047) - _19685) * _5910) <= ((0.100000001490116119384765625f * length(_20047 * _5910)) + 8.0f);
                }
                else
                {
                    _20049 = _5889;
                }
                _20048 = _20049;
            }
            else
            {
                _20048 = true;
            }
            bool _5924 = !_20048;
            bool _23569 = _5924 ? false : _5828;
            bool _23570 = _5924 ? false : _5815;
            bool _20126;
            float4 _20165;
            if (!(((_5789 && _5802) && _23570) && _23569))
            {
                float4 _5946 = _20104 * float4(_5854, _5856, float(_23570), float(_23569));
                float _5948 = dot(_5946, 1.0f.xxxx);
                bool _5951 = !(_5948 > 0.0f);
                float4 _20166;
                if (!_5951)
                {
                    _20166 = _5946 / _5948.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11467;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11467);
                    }
                    _20166 = 0.0f.xxxx;
                }
                _20165 = _20166;
                _20126 = _5951;
            }
            else
            {
                _20165 = _20104;
                _20126 = false;
            }
            _21918 = float3(_5854, _5856, _20033);
            _20164 = _20165;
            _20125 = _20126;
        }
        else
        {
            _21918 = float3(float(_10911), _5773, 0.0f);
            _20164 = _20104;
            _20125 = false;
        }
        bool _5969 = !_20125;
        float4 _20257;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5969)
        {
            float _5976 = _20164.x + _20164.y;
            float4 _20258;
            if (_5976 > 0.001000000047497451305389404296875f)
            {
                _20258 = float4(_20164.x / _5976, _20164.y / _5976, 0.0f, 0.0f);
            }
            else
            {
                _20258 = float4(_5538, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20257 = _20258;
        }
        else
        {
            _20257 = _20164;
        }
        float4 _20434;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5969) && _10911)
        {
            float _20231;
            do
            {
                uint4 _11607 = r_warped_motion_qdata_tp1.Load(int3(_19902, 0));
                uint _11608 = _11607.x;
                if (_11608 != 0u)
                {
                    float _20230;
                    if (_11608 == 0u)
                    {
                        _20230 = -1.0f;
                    }
                    else
                    {
                        _20230 = float((_11608 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20231 = _20230;
                    break;
                }
                int _20213;
                uint _20214;
                _20214 = _11608;
                _20213 = -1;
                uint _20229;
                for (; _20213 <= 1; _20214 = _20229, _20213++)
                {
                    _20229 = _20214;
                    for (int _20227 = -1; _20227 <= 1; )
                    {
                        _20229 = max(_20229, r_warped_motion_qdata_tp1.Load(int3(clamp(_19902 + int2(_20227, _20213), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20227++;
                        continue;
                    }
                }
                if (_20214 != 0u)
                {
                    float _20226;
                    if (_20214 == 0u)
                    {
                        _20226 = -1.0f;
                    }
                    else
                    {
                        _20226 = float((_20214 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20231 = _20226;
                    break;
                }
                uint _20216;
                _20216 = 4294967295u;
                uint _23202;
                for (int _20215 = 0; _20215 < 8; _20216 = _23202, _20215++)
                {
                    int _20219 = 0;
                    for (;;)
                    {
                        if (_20219 < 5)
                        {
                            int2 _11558 = _19902 + (_1239[_20215] * _1248[_20219].xx);
                            bool _11561 = any(bool2(_11558.x < int2(0, 0).x, _11558.y < int2(0, 0).y));
                            bool _11569;
                            if (!_11561)
                            {
                                _11569 = any(bool2(_11558.x >= cbFI_MvDepthLaneSize.x, _11558.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11569 = _11561;
                            }
                            if (_11569)
                            {
                                _23202 = _20216;
                                break;
                            }
                            uint4 _11647 = r_warped_motion_qdata_tp1.Load(int3(_11558, 0));
                            uint _11648 = _11647.x;
                            if (_11648 != 0u)
                            {
                                _23202 = min(_20216, _11648);
                                break;
                            }
                            _20219++;
                            continue;
                        }
                        else
                        {
                            _23202 = _20216;
                            break;
                        }
                    }
                }
                float _20218;
                if (_20216 == 4294967295u)
                {
                    _20218 = -1.0f;
                }
                else
                {
                    float _20217;
                    if (_20216 == 0u)
                    {
                        _20217 = -1.0f;
                    }
                    else
                    {
                        _20217 = float((_20216 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20218 = _20217;
                }
                _20231 = _20218;
                break;
            } while(false);
            float _6012 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6015 = r_warped_motion_qdata_tp1.Load(int3(_19902, 0)).x == 0u;
            bool _6021;
            if (_6015)
            {
                bool _11673 = all(bool2(_19681.x > 0.0f.xx.x, _19681.y > 0.0f.xx.y));
                bool _11679;
                if (_11673)
                {
                    _11679 = all(bool2(_19681.x < 1.0f.xx.x, _19681.y < 1.0f.xx.y));
                }
                else
                {
                    _11679 = _11673;
                }
                _6021 = _11679;
            }
            else
            {
                _6021 = _6015;
            }
            bool _6026;
            if (_6021)
            {
                bool _11684 = all(bool2(_19683.x > 0.0f.xx.x, _19683.y > 0.0f.xx.y));
                bool _11690;
                if (_11684)
                {
                    _11690 = all(bool2(_19683.x < 1.0f.xx.x, _19683.y < 1.0f.xx.y));
                }
                else
                {
                    _11690 = _11684;
                }
                _6026 = _11690;
            }
            else
            {
                _6026 = _6021;
            }
            bool _20243;
            float4 _20252;
            if (_6026)
            {
                uint _11697_dummy_parameter;
                float _11721 = log((r_depth_tm1.Load(int3(int2(floor(_19681 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11697_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _11729_dummy_parameter;
                float _11753 = log((r_depth_tp1.Load(int3(int2(floor(_19683 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11729_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _6037 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6044;
                if (_6037)
                {
                    _6044 = _11753 > (_11721 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6044 = _6037;
                }
                bool _20248;
                float4 _20270;
                if (_6044)
                {
                    _20270 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20248 = true;
                }
                else
                {
                    bool _6050 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6057;
                    if (_6050)
                    {
                        _6057 = _11721 > (_11753 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6057 = _6050;
                    }
                    bool4 _23571 = _6057.xxxx;
                    _20270 = float4(_23571.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20257.x, _23571.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20257.y, _23571.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20257.z, _23571.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20257.w);
                    _20248 = _6057 ? true : false;
                }
                _20252 = _20270;
                _20243 = _20248;
            }
            else
            {
                _20252 = _20257;
                _20243 = false;
            }
            float4 _20325;
            if (_20243)
            {
                _20325 = 1.0f.xxxx;
            }
            else
            {
                bool _6068 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6074;
                if (_6068)
                {
                    _6074 = _20252.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6074 = _6068;
                }
                bool _6079;
                if (_6074)
                {
                    bool _11759 = all(bool2(_19683.x > 0.0f.xx.x, _19683.y > 0.0f.xx.y));
                    bool _11765;
                    if (_11759)
                    {
                        _11765 = all(bool2(_19683.x < 1.0f.xx.x, _19683.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11765 = _11759;
                    }
                    _6079 = _11765;
                }
                else
                {
                    _6079 = _6074;
                }
                float4 _20326;
                if (_6079)
                {
                    float _20279;
                    if (_20231 >= 0.0f)
                    {
                        _20279 = _20231 - _6012;
                    }
                    else
                    {
                        float _20275;
                        _20275 = 2.0f;
                        float _11822;
                        for (int _20274 = 0; _20274 < 24; _20275 = _11822, _20274++)
                        {
                            float _11786 = float(_20274 & 7) * 0.785398185253143310546875f;
                            int _11788 = _20274 >> 3;
                            int _20276;
                            if (_11788 == 0)
                            {
                                _20276 = 16;
                            }
                            else
                            {
                                _20276 = (_11788 == 1) ? 48 : 96;
                            }
                            uint _11854_dummy_parameter;
                            _11822 = min(_20275, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19683 + ((cbFI_MvDepthLaneSizeRcp * float(_20276)) * float2(cos(_11786), sin(_11786))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11854_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20279 = _20275;
                    }
                    uint _11886_dummy_parameter;
                    float4 _20327;
                    if (r_depth_tp1.Load(int3(int2(floor(_19683 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11886_dummy_parameter))))), 0)).x > ((exp((_20279 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20327 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20327 = 1.0f.xxxx;
                    }
                    _20326 = _20327;
                }
                else
                {
                    _20326 = 1.0f.xxxx;
                }
                _20325 = _20326;
            }
            bool _6107 = _20231 >= 0.0f;
            bool _6108 = (!_20243) && _6107;
            bool _6115;
            if (_6108)
            {
                _6115 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6115 = _6108;
            }
            bool _6121;
            if (_6115)
            {
                _6121 = _20252.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6121 = _6115;
            }
            bool _6126;
            if (_6121)
            {
                bool _11910 = all(bool2(_19681.x > 0.0f.xx.x, _19681.y > 0.0f.xx.y));
                bool _11916;
                if (_11910)
                {
                    _11916 = all(bool2(_19681.x < 1.0f.xx.x, _19681.y < 1.0f.xx.y));
                }
                else
                {
                    _11916 = _11910;
                }
                _6126 = _11916;
            }
            else
            {
                _6126 = _6121;
            }
            float4 _20350;
            if (_6126)
            {
                float _20319;
                if (_6107)
                {
                    _20319 = _20231 - _6012;
                }
                else
                {
                    float _20315;
                    _20315 = 2.0f;
                    float _11973;
                    for (int _20314 = 0; _20314 < 24; _20315 = _11973, _20314++)
                    {
                        float _11937 = float(_20314 & 7) * 0.785398185253143310546875f;
                        int _11939 = _20314 >> 3;
                        int _20316;
                        if (_11939 == 0)
                        {
                            _20316 = 16;
                        }
                        else
                        {
                            _20316 = (_11939 == 1) ? 48 : 96;
                        }
                        uint _11989_dummy_parameter;
                        _11973 = min(_20315, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19681 + ((cbFI_MvDepthLaneSizeRcp * float(_20316)) * float2(cos(_11937), sin(_11937))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11989_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20319 = _20315;
                }
                uint _12037_dummy_parameter;
                float4 _20351;
                if (r_depth_tm1.Load(int3(int2(floor(_19681 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12037_dummy_parameter))))), 0)).x > ((exp((_20319 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19377 = _20325;
                    _19377.x = 0.0f;
                    _20351 = _19377;
                }
                else
                {
                    _20351 = _20325;
                }
                _20350 = _20351;
            }
            else
            {
                _20350 = _20325;
            }
            float4 _20363;
            if (_6108)
            {
                float _12063 = (exp(((_20231 - _6012) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6164 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6170;
                if (_6164)
                {
                    _6170 = _20252.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6170 = _6164;
                }
                bool _6175;
                if (_6170)
                {
                    bool _12068 = all(bool2(_19685.x > 0.0f.xx.x, _19685.y > 0.0f.xx.y));
                    bool _12074;
                    if (_12068)
                    {
                        _12074 = all(bool2(_19685.x < 1.0f.xx.x, _19685.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12074 = _12068;
                    }
                    _6175 = _12074;
                }
                else
                {
                    _6175 = _6170;
                }
                bool _6183;
                if (_6175)
                {
                    uint _12081_dummy_parameter;
                    _6183 = r_depth_tp1.Load(int3(int2(floor(_19685 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12081_dummy_parameter))))), 0)).x > _12063;
                }
                else
                {
                    _6183 = _6175;
                }
                float4 _20361;
                if (_6183)
                {
                    float4 _19380 = _20350;
                    _19380.w = 0.0f;
                    _20361 = _19380;
                }
                else
                {
                    _20361 = _20350;
                }
                bool _6190 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6196;
                if (_6190)
                {
                    _6196 = _20252.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6196 = _6190;
                }
                bool _6201;
                if (_6196)
                {
                    bool _12098 = all(bool2(_19684.x > 0.0f.xx.x, _19684.y > 0.0f.xx.y));
                    bool _12104;
                    if (_12098)
                    {
                        _12104 = all(bool2(_19684.x < 1.0f.xx.x, _19684.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12104 = _12098;
                    }
                    _6201 = _12104;
                }
                else
                {
                    _6201 = _6196;
                }
                bool _6209;
                if (_6201)
                {
                    uint _12111_dummy_parameter;
                    _6209 = r_depth_tm1.Load(int3(int2(floor(_19684 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12111_dummy_parameter))))), 0)).x > _12063;
                }
                else
                {
                    _6209 = _6201;
                }
                float4 _20364;
                if (_6209)
                {
                    float4 _19383 = _20361;
                    _19383.z = 0.0f;
                    _20364 = _19383;
                }
                else
                {
                    _20364 = _20361;
                }
                _20363 = _20364;
            }
            else
            {
                _20363 = _20350;
            }
            float4 _20435;
            if (any(bool4(_20363.x < 1.0f.xxxx.x, _20363.y < 1.0f.xxxx.y, _20363.z < 1.0f.xxxx.z, _20363.w < 1.0f.xxxx.w)))
            {
                float4 _6220 = _20252 * _20363;
                float _6222 = dot(_6220, 1.0f.xxxx);
                float4 _20436;
                if (_6222 > 0.0f)
                {
                    _20436 = _6220 / _6222.xxxx;
                }
                else
                {
                    bool _6233 = _20363.y == 0.0f;
                    bool _6239;
                    if (_6233)
                    {
                        _6239 = _20363.x > 0.0f;
                    }
                    else
                    {
                        _6239 = _6233;
                    }
                    bool _6244;
                    if (_6239)
                    {
                        bool _12128 = all(bool2(_19681.x > 0.0f.xx.x, _19681.y > 0.0f.xx.y));
                        bool _12134;
                        if (_12128)
                        {
                            _12134 = all(bool2(_19681.x < 1.0f.xx.x, _19681.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12134 = _12128;
                        }
                        _6244 = _12134;
                    }
                    else
                    {
                        _6244 = _6239;
                    }
                    float4 _20437;
                    if (_6244)
                    {
                        _20437 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6249 = _20363.x == 0.0f;
                        bool _6255;
                        if (_6249)
                        {
                            _6255 = _20363.y > 0.0f;
                        }
                        else
                        {
                            _6255 = _6249;
                        }
                        bool _6260;
                        if (_6255)
                        {
                            bool _12139 = all(bool2(_19683.x > 0.0f.xx.x, _19683.y > 0.0f.xx.y));
                            bool _12145;
                            if (_12139)
                            {
                                _12145 = all(bool2(_19683.x < 1.0f.xx.x, _19683.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12145 = _12139;
                            }
                            _6260 = _12145;
                        }
                        else
                        {
                            _6260 = _6255;
                        }
                        bool4 _23574 = _6260.xxxx;
                        _20437 = float4(_23574.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20252.x, _23574.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20252.y, _23574.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20252.z, _23574.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20252.w);
                    }
                    _20436 = _20437;
                }
                _20435 = _20436;
            }
            else
            {
                _20435 = _20252;
            }
            _20434 = _20435;
        }
        else
        {
            _20434 = _20257;
        }
        float4 _21164;
        bool _21470;
        float3 _21659;
        if (((cbFI_pad0 & 32768u) != 0u) && _5969)
        {
            bool _6277 = _20434.x > 0.00999999977648258209228515625f;
            bool _6280 = _20434.y > 0.00999999977648258209228515625f;
            bool _6289 = (_20434.z + _20434.w) > 0.0199999995529651641845703125f;
            bool _6295;
            if (_6289)
            {
                bool _12150 = all(bool2(_19684.x > 0.0f.xx.x, _19684.y > 0.0f.xx.y));
                bool _12156;
                if (_12150)
                {
                    _12156 = all(bool2(_19684.x < 1.0f.xx.x, _19684.y < 1.0f.xx.y));
                }
                else
                {
                    _12156 = _12150;
                }
                _6295 = _12156;
            }
            else
            {
                _6295 = _6289;
            }
            bool _6300;
            if (_6295)
            {
                bool _12161 = all(bool2(_19685.x > 0.0f.xx.x, _19685.y > 0.0f.xx.y));
                bool _12167;
                if (_12161)
                {
                    _12167 = all(bool2(_19685.x < 1.0f.xx.x, _19685.y < 1.0f.xx.y));
                }
                else
                {
                    _12167 = _12161;
                }
                _6300 = _12167;
            }
            else
            {
                _6300 = _6295;
            }
            bool _6307;
            if (_6300)
            {
                float _20450;
                do
                {
                    bool _12250 = all(bool2(_19684.x > 0.0f.xx.x, _19684.y > 0.0f.xx.y));
                    bool _12256;
                    if (_12250)
                    {
                        _12256 = all(bool2(_19684.x < 1.0f.xx.x, _19684.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12256 = _12250;
                    }
                    bool _12187 = !_12256;
                    bool _12194;
                    if (!_12187)
                    {
                        bool _12261 = all(bool2(_19685.x > 0.0f.xx.x, _19685.y > 0.0f.xx.y));
                        bool _12267;
                        if (_12261)
                        {
                            _12267 = all(bool2(_19685.x < 1.0f.xx.x, _19685.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12267 = _12261;
                        }
                        _12194 = !_12267;
                    }
                    else
                    {
                        _12194 = _12187;
                    }
                    if (_12194)
                    {
                        _20450 = 0.0f;
                        break;
                    }
                    uint _12274_dummy_parameter;
                    uint _12290_dummy_parameter;
                    float4x4 _20449;
                    do
                    {
                        float4x4 _12304;
                        bool _20448;
                        do
                        {
                            _12304 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20448 = false;
                                break;
                            }
                            uint _12338 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12338 + 32u) * 4 + 0) != 1u)
                            {
                                _20448 = false;
                                break;
                            }
                            uint _20445;
                            _20445 = 0u;
                            for (; _20445 < 4u; _20445++)
                            {
                                for (uint _20446 = 0u; _20446 < 4u; )
                                {
                                    _12304[_20445][_20446] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12338 + 16u) + (_20445 * 4u)) + _20446) * 4 + 0));
                                    _20446++;
                                    continue;
                                }
                            }
                            _20448 = true;
                            break;
                        } while(false);
                        if (_20448)
                        {
                            _20449 = _12304;
                            break;
                        }
                        _20449 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12215 = mul(float4((float2(_19684.x, 1.0f - _19684.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19684 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12274_dummy_parameter))))), 0)).x, 1.0f), _20449);
                    float _12217 = _12215.w;
                    if (abs(_12217) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20450 = 0.0f;
                        break;
                    }
                    float _12228 = abs(cbFI_DeviceToViewDepth.y / ((_12215.z / _12217) - cbFI_DeviceToViewDepth.x));
                    float _12231 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19685 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12290_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20450 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12228 - _12231) / max(max(_12228, _12231), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6307 = _20450 < 0.5f;
            }
            else
            {
                _6307 = _6300;
            }
            float4 _20469;
            if (_6307)
            {
                uint _12442_dummy_parameter;
                uint _12473_dummy_parameter;
                float4 _20470;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19684 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12442_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19685 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12473_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20470 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20470 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20469 = _20470;
            }
            else
            {
                _20469 = 1.0f.xxxx;
            }
            bool _6331;
            if (_10911)
            {
                bool _12502 = all(bool2(_19681.x > 0.0f.xx.x, _19681.y > 0.0f.xx.y));
                bool _12508;
                if (_12502)
                {
                    _12508 = all(bool2(_19681.x < 1.0f.xx.x, _19681.y < 1.0f.xx.y));
                }
                else
                {
                    _12508 = _12502;
                }
                _6331 = _12508;
            }
            else
            {
                _6331 = _10911;
            }
            bool _6337;
            if (_10911)
            {
                bool _12513 = all(bool2(_19683.x > 0.0f.xx.x, _19683.y > 0.0f.xx.y));
                bool _12519;
                if (_12513)
                {
                    _12519 = all(bool2(_19683.x < 1.0f.xx.x, _19683.y < 1.0f.xx.y));
                }
                else
                {
                    _12519 = _12513;
                }
                _6337 = _12519;
            }
            else
            {
                _6337 = _10911;
            }
            bool _6343;
            if (_10943)
            {
                bool _12524 = all(bool2(_19684.x > 0.0f.xx.x, _19684.y > 0.0f.xx.y));
                bool _12530;
                if (_12524)
                {
                    _12530 = all(bool2(_19684.x < 1.0f.xx.x, _19684.y < 1.0f.xx.y));
                }
                else
                {
                    _12530 = _12524;
                }
                _6343 = _12530;
            }
            else
            {
                _6343 = _10943;
            }
            bool _6349;
            if (_10943)
            {
                bool _12535 = all(bool2(_19685.x > 0.0f.xx.x, _19685.y > 0.0f.xx.y));
                bool _12541;
                if (_12535)
                {
                    _12541 = all(bool2(_19685.x < 1.0f.xx.x, _19685.y < 1.0f.xx.y));
                }
                else
                {
                    _12541 = _12535;
                }
                _6349 = _12541;
            }
            else
            {
                _6349 = _10943;
            }
            bool _6352 = _6343 != _6349;
            bool _6358;
            if (_6352)
            {
                _6358 = _6331 || _6337;
            }
            else
            {
                _6358 = _6352;
            }
            float4 _20572;
            if (_6358)
            {
                float4 _19410 = _20469;
                _19410.z = 0.0f;
                _19410.w = 0.0f;
                _20572 = _19410;
            }
            else
            {
                _20572 = _20469;
            }
            bool _6365 = _6331 && _6277;
            bool _6368 = _6337 && _6280;
            float4 _20677;
            float3 _21768;
            if (_6365 || _6368)
            {
                float _20567;
                do
                {
                    uint4 _12680 = r_warped_motion_qdata_tp1.Load(int3(_19902, 0));
                    uint _12681 = _12680.x;
                    if (_12681 != 0u)
                    {
                        float _20566;
                        if (_12681 == 0u)
                        {
                            _20566 = -1.0f;
                        }
                        else
                        {
                            _20566 = float((_12681 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20567 = _20566;
                        break;
                    }
                    int _20549;
                    uint _20550;
                    _20550 = _12681;
                    _20549 = -1;
                    uint _20565;
                    for (; _20549 <= 1; _20550 = _20565, _20549++)
                    {
                        _20565 = _20550;
                        for (int _20563 = -1; _20563 <= 1; )
                        {
                            _20565 = max(_20565, r_warped_motion_qdata_tp1.Load(int3(clamp(_19902 + int2(_20563, _20549), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20563++;
                            continue;
                        }
                    }
                    if (_20550 != 0u)
                    {
                        float _20562;
                        if (_20550 == 0u)
                        {
                            _20562 = -1.0f;
                        }
                        else
                        {
                            _20562 = float((_20550 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20567 = _20562;
                        break;
                    }
                    uint _20552;
                    _20552 = 4294967295u;
                    uint _23203;
                    for (int _20551 = 0; _20551 < 8; _20552 = _23203, _20551++)
                    {
                        int _20555 = 0;
                        for (;;)
                        {
                            if (_20555 < 5)
                            {
                                int2 _12631 = _19902 + (_1239[_20551] * _1248[_20555].xx);
                                bool _12634 = any(bool2(_12631.x < int2(0, 0).x, _12631.y < int2(0, 0).y));
                                bool _12642;
                                if (!_12634)
                                {
                                    _12642 = any(bool2(_12631.x >= cbFI_MvDepthLaneSize.x, _12631.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12642 = _12634;
                                }
                                if (_12642)
                                {
                                    _23203 = _20552;
                                    break;
                                }
                                uint4 _12720 = r_warped_motion_qdata_tp1.Load(int3(_12631, 0));
                                uint _12721 = _12720.x;
                                if (_12721 != 0u)
                                {
                                    _23203 = min(_20552, _12721);
                                    break;
                                }
                                _20555++;
                                continue;
                            }
                            else
                            {
                                _23203 = _20552;
                                break;
                            }
                        }
                    }
                    float _20554;
                    if (_20552 == 4294967295u)
                    {
                        _20554 = -1.0f;
                    }
                    else
                    {
                        float _20553;
                        if (_20552 == 0u)
                        {
                            _20553 = -1.0f;
                        }
                        else
                        {
                            _20553 = float((_20552 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20554 = _20553;
                    }
                    _20567 = _20554;
                    break;
                } while(false);
                bool _6376 = _20567 < 0.0f;
                float _20568;
                if (_6376)
                {
                    _20568 = 0.0f;
                }
                else
                {
                    _20568 = _20567 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12742_dummy_parameter;
                uint _12774_dummy_parameter;
                float4 _20605;
                if ((_6376 && _6365) && _6368)
                {
                    uint _12806_dummy_parameter;
                    float _12830 = log((r_depth_tm1.Load(int3(int2(floor(_19681 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12806_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12838_dummy_parameter;
                    float _12862 = log((r_depth_tp1.Load(int3(int2(floor(_19683 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12838_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20606;
                    if (_12830 > (_12862 + 0.07999999821186065673828125f))
                    {
                        float4 _19414 = _20572;
                        _19414.x = 0.0f;
                        _20606 = _19414;
                    }
                    else
                    {
                        float4 _20607;
                        if (_12862 > (_12830 + 0.07999999821186065673828125f))
                        {
                            float4 _19416 = _20572;
                            _19416.y = 0.0f;
                            _20607 = _19416;
                        }
                        else
                        {
                            _20607 = _20572;
                        }
                        _20606 = _20607;
                    }
                    _20605 = _20606;
                }
                else
                {
                    _20605 = _20572;
                }
                float _6428 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6430 = _20567 >= 0.0f;
                float _20588;
                if (_6430)
                {
                    _20588 = _20567 - _6428;
                }
                else
                {
                    float _20584;
                    if (_6365)
                    {
                        float _20583;
                        _20583 = 2.0f;
                        float _12920;
                        for (int _20582 = 0; _20582 < 24; _20583 = _12920, _20582++)
                        {
                            float _12884 = float(_20582 & 7) * 0.785398185253143310546875f;
                            int _12886 = _20582 >> 3;
                            int _20585;
                            if (_12886 == 0)
                            {
                                _20585 = 16;
                            }
                            else
                            {
                                _20585 = (_12886 == 1) ? 48 : 96;
                            }
                            uint _12936_dummy_parameter;
                            _12920 = min(_20583, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19681 + ((cbFI_MvDepthLaneSizeRcp * float(_20585)) * float2(cos(_12884), sin(_12884))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12936_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20584 = _20583;
                    }
                    else
                    {
                        _20584 = 0.0f;
                    }
                    _20588 = _20584;
                }
                float _20595;
                if (_6430)
                {
                    _20595 = _20567 - _6428;
                }
                else
                {
                    float _20591;
                    if (_6368)
                    {
                        float _20590;
                        _20590 = 2.0f;
                        float _13034;
                        for (int _20589 = 0; _20589 < 24; _20590 = _13034, _20589++)
                        {
                            float _12998 = float(_20589 & 7) * 0.785398185253143310546875f;
                            int _13000 = _20589 >> 3;
                            int _20592;
                            if (_13000 == 0)
                            {
                                _20592 = 16;
                            }
                            else
                            {
                                _20592 = (_13000 == 1) ? 48 : 96;
                            }
                            uint _13066_dummy_parameter;
                            _13034 = min(_20590, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19683 + ((cbFI_MvDepthLaneSizeRcp * float(_20592)) * float2(cos(_12998), sin(_12998))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13066_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20591 = _20590;
                    }
                    else
                    {
                        _20591 = 0.0f;
                    }
                    _20595 = _20591;
                }
                float _20596;
                if (_6365)
                {
                    uint _13098_dummy_parameter;
                    _20596 = r_depth_tm1.Load(int3(int2(floor(_19681 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13098_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20596 = 0.0f;
                }
                float _20597;
                if (_6368)
                {
                    uint _13117_dummy_parameter;
                    _20597 = r_depth_tp1.Load(int3(int2(floor(_19683 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13117_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20597 = 0.0f;
                }
                bool _6485;
                if (_6365)
                {
                    _6485 = _20596 > ((exp((_20588 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6485 = _6365;
                }
                float4 _20613;
                if (_6485)
                {
                    float4 _19418 = _20605;
                    _19418.x = 0.0f;
                    _20613 = _19418;
                }
                else
                {
                    _20613 = _20605;
                }
                bool _6497;
                if (_6368)
                {
                    _6497 = _20597 > ((exp((_20595 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6497 = _6368;
                }
                float4 _20615;
                if (_6497)
                {
                    float4 _19420 = _20613;
                    _19420.y = 0.0f;
                    _20615 = _19420;
                }
                else
                {
                    _20615 = _20613;
                }
                float4 _20678;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6430)
                {
                    bool _6517;
                    if (_6365)
                    {
                        _6517 = _20596 < ((exp((_20588 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6517 = _6365;
                    }
                    float4 _20617;
                    if (_6517)
                    {
                        float4 _19422 = _20615;
                        _19422.x = 0.0f;
                        _20617 = _19422;
                    }
                    else
                    {
                        _20617 = _20615;
                    }
                    bool _6529;
                    if (_6368)
                    {
                        _6529 = _20597 < ((exp((_20595 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6529 = _6368;
                    }
                    float4 _20679;
                    if (_6529)
                    {
                        float4 _19424 = _20617;
                        _19424.y = 0.0f;
                        _20679 = _19424;
                    }
                    else
                    {
                        _20679 = _20617;
                    }
                    _20678 = _20679;
                }
                else
                {
                    _20678 = _20615;
                }
                _21768 = float3(_20568, log((r_depth_tm1.Load(int3(int2(floor(_19681 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12742_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_19683 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12774_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _20677 = _20678;
            }
            else
            {
                _21768 = float3(0.0f, 0.0f, 0.5f);
                _20677 = _20572;
            }
            bool _6540 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6289;
            bool _6546;
            if (_6540)
            {
                _6546 = _6343 || _6349;
            }
            else
            {
                _6546 = _6540;
            }
            float4 _20720;
            if (_6546)
            {
                float _20672;
                do
                {
                    uint4 _13296 = r_warped_motion_qdata_tp1.Load(int3(_19902, 0));
                    uint _13297 = _13296.x;
                    if (_13297 != 0u)
                    {
                        float _20671;
                        if (_13297 == 0u)
                        {
                            _20671 = -1.0f;
                        }
                        else
                        {
                            _20671 = float((_13297 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20672 = _20671;
                        break;
                    }
                    int _20654;
                    uint _20655;
                    _20655 = _13297;
                    _20654 = -1;
                    uint _20670;
                    for (; _20654 <= 1; _20655 = _20670, _20654++)
                    {
                        _20670 = _20655;
                        for (int _20668 = -1; _20668 <= 1; )
                        {
                            _20670 = max(_20670, r_warped_motion_qdata_tp1.Load(int3(clamp(_19902 + int2(_20668, _20654), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20668++;
                            continue;
                        }
                    }
                    if (_20655 != 0u)
                    {
                        float _20667;
                        if (_20655 == 0u)
                        {
                            _20667 = -1.0f;
                        }
                        else
                        {
                            _20667 = float((_20655 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20672 = _20667;
                        break;
                    }
                    uint _20657;
                    _20657 = 4294967295u;
                    uint _23204;
                    for (int _20656 = 0; _20656 < 8; _20657 = _23204, _20656++)
                    {
                        int _20660 = 0;
                        for (;;)
                        {
                            if (_20660 < 5)
                            {
                                int2 _13247 = _19902 + (_1239[_20656] * _1248[_20660].xx);
                                bool _13250 = any(bool2(_13247.x < int2(0, 0).x, _13247.y < int2(0, 0).y));
                                bool _13258;
                                if (!_13250)
                                {
                                    _13258 = any(bool2(_13247.x >= cbFI_MvDepthLaneSize.x, _13247.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13258 = _13250;
                                }
                                if (_13258)
                                {
                                    _23204 = _20657;
                                    break;
                                }
                                uint4 _13336 = r_warped_motion_qdata_tp1.Load(int3(_13247, 0));
                                uint _13337 = _13336.x;
                                if (_13337 != 0u)
                                {
                                    _23204 = min(_20657, _13337);
                                    break;
                                }
                                _20660++;
                                continue;
                            }
                            else
                            {
                                _23204 = _20657;
                                break;
                            }
                        }
                    }
                    float _20659;
                    if (_20657 == 4294967295u)
                    {
                        _20659 = -1.0f;
                    }
                    else
                    {
                        float _20658;
                        if (_20657 == 0u)
                        {
                            _20658 = -1.0f;
                        }
                        else
                        {
                            _20658 = float((_20657 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20659 = _20658;
                    }
                    _20672 = _20659;
                    break;
                } while(false);
                float4 _20721;
                if (_20672 >= 0.0f)
                {
                    float _13358 = (exp((_20672 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6565;
                    if (_6343)
                    {
                        uint _13365_dummy_parameter;
                        _6565 = r_depth_tm1.Load(int3(int2(floor(_19684 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13365_dummy_parameter))))), 0)).x > _13358;
                    }
                    else
                    {
                        _6565 = _6343;
                    }
                    float4 _20690;
                    if (_6565)
                    {
                        float4 _19426 = _20677;
                        _19426.z = 0.0f;
                        _20690 = _19426;
                    }
                    else
                    {
                        _20690 = _20677;
                    }
                    bool _6577;
                    if (_6349)
                    {
                        uint _13384_dummy_parameter;
                        _6577 = r_depth_tp1.Load(int3(int2(floor(_19685 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13384_dummy_parameter))))), 0)).x > _13358;
                    }
                    else
                    {
                        _6577 = _6349;
                    }
                    float4 _20722;
                    if (_6577)
                    {
                        float4 _19428 = _20690;
                        _19428.w = 0.0f;
                        _20722 = _19428;
                    }
                    else
                    {
                        _20722 = _20690;
                    }
                    _20721 = _20722;
                }
                else
                {
                    _20721 = _20677;
                }
                _20720 = _20721;
            }
            else
            {
                _20720 = _20677;
            }
            bool _6585 = _6331 != _6337;
            bool _6592;
            if (_6585)
            {
                _6592 = _6331 ? _6277 : _6280;
            }
            else
            {
                _6592 = _6585;
            }
            bool _6599;
            if (_6592)
            {
                _6599 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6599 = _6592;
            }
            float4 _20823;
            if (_6599)
            {
                bool2 _6604 = _6331.xx;
                float2 _6605 = float2(_6604.x ? _19681.x : _19683.x, _6604.y ? _19681.y : _19683.y);
                float _20704;
                if (_6331)
                {
                    uint _13403_dummy_parameter;
                    _20704 = r_depth_tm1.Load(int3(int2(floor(_6605 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13403_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13419_dummy_parameter;
                    _20704 = r_depth_tp1.Load(int3(int2(floor(_6605 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13419_dummy_parameter))))), 0)).x;
                }
                float4x4 _20711;
                if (_6331)
                {
                    float4x4 _20700;
                    do
                    {
                        float4x4 _13433;
                        bool _20699;
                        do
                        {
                            _13433 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20699 = false;
                                break;
                            }
                            uint _13467 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13467 + 32u) * 4 + 0) != 1u)
                            {
                                _20699 = false;
                                break;
                            }
                            uint _20696;
                            _20696 = 0u;
                            for (; _20696 < 4u; _20696++)
                            {
                                for (uint _20697 = 0u; _20697 < 4u; )
                                {
                                    _13433[_20696][_20697] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13467 + 16u) + (_20696 * 4u)) + _20697) * 4 + 0));
                                    _20697++;
                                    continue;
                                }
                            }
                            _20699 = true;
                            break;
                        } while(false);
                        if (_20699)
                        {
                            _20700 = _13433;
                            break;
                        }
                        _20700 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20711 = _20700;
                }
                else
                {
                    float4x4 _20695;
                    do
                    {
                        float4x4 _13539;
                        bool _20694;
                        do
                        {
                            _13539 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20694 = false;
                                break;
                            }
                            uint _13573 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13573 + 32u) * 4 + 0) != 1u)
                            {
                                _20694 = false;
                                break;
                            }
                            uint _20691;
                            _20691 = 0u;
                            for (; _20691 < 4u; _20691++)
                            {
                                for (uint _20692 = 0u; _20692 < 4u; )
                                {
                                    _13539[_20691][_20692] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13573 + (_20691 * 4u)) + _20692) * 4 + 0));
                                    _20692++;
                                    continue;
                                }
                            }
                            _20694 = true;
                            break;
                        } while(false);
                        if (_20694)
                        {
                            _20695 = _13539;
                            break;
                        }
                        _20695 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20711 = _20695;
                }
                float2 _20712;
                do
                {
                    float _13650 = _6605.x;
                    float _13653 = 1.0f - _6605.y;
                    float4 _13664 = mul(float4((float2(_13650, _13653) * 2.0f) - 1.0f.xx, _20704, 1.0f), _20711);
                    float _13666 = _13664.w;
                    if (!(_13666 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20712 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13679 = ((_13664.xy / _13666.xx) + 1.0f.xx) * 0.5f;
                    _20712 = float2(_13679.x - _13650, _13653 - _13679.y);
                    break;
                } while(false);
                float2 _6635 = float2(cbFI_DisplaySize);
                float4 _20824;
                if (!(length(((_6605 + _20712) - float2(_6604.x ? _19683.x : _19681.x, _6604.y ? _19683.y : _19681.y)) * _6635) <= ((0.100000001490116119384765625f * length(_20712 * _6635)) + 8.0f)))
                {
                    float4 _20825;
                    if (_6331)
                    {
                        float4 _19438 = _20720;
                        _19438.x = 0.0f;
                        _20825 = _19438;
                    }
                    else
                    {
                        float4 _19440 = _20720;
                        _19440.y = 0.0f;
                        _20825 = _19440;
                    }
                    _20824 = _20825;
                }
                else
                {
                    _20824 = _20720;
                }
                _20823 = _20824;
            }
            else
            {
                _20823 = _20720;
            }
            float4 _6660 = _20434 * _20823;
            float _6662 = dot(_6660, 1.0f.xxxx);
            float4 _21165;
            bool _21471;
            if (_6662 > 0.0f)
            {
                _21471 = _20125;
                _21165 = _6660 / _6662.xxxx;
            }
            else
            {
                bool _6673 = any(bool4(_20823.x < 1.0f.xxxx.x, _20823.y < 1.0f.xxxx.y, _20823.z < 1.0f.xxxx.z, _20823.w < 1.0f.xxxx.w));
                if (_6673)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13701;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13701);
                    }
                }
                bool4 _23577 = _6673.xxxx;
                _21471 = _6673 ? true : _20125;
                _21165 = float4(_23577.x ? 0.0f.xxxx.x : _20434.x, _23577.y ? 0.0f.xxxx.y : _20434.y, _23577.z ? 0.0f.xxxx.z : _20434.z, _23577.w ? 0.0f.xxxx.w : _20434.w);
            }
            _21659 = _21768;
            _21470 = _21471;
            _21164 = _21165;
        }
        else
        {
            _21659 = float3(0.0f, 0.0f, 0.5f);
            _21470 = _20125;
            _21164 = _20434;
        }
        uint _6682 = (cbFI_pad0 >> 24u) & 31u;
        uint _6686 = (cbFI_pad0 >> 16u) & 255u;
        bool _6688 = _6682 != 0u;
        bool _6690 = _6686 == 12u;
        bool _6693 = _6686 == 13u;
        float4 _21185;
        if ((_6688 || _6690) || _6693)
        {
            float _20831;
            do
            {
                bool _13785 = all(bool2(_19684.x > 0.0f.xx.x, _19684.y > 0.0f.xx.y));
                bool _13791;
                if (_13785)
                {
                    _13791 = all(bool2(_19684.x < 1.0f.xx.x, _19684.y < 1.0f.xx.y));
                }
                else
                {
                    _13791 = _13785;
                }
                bool _13722 = !_13791;
                bool _13729;
                if (!_13722)
                {
                    bool _13796 = all(bool2(_19685.x > 0.0f.xx.x, _19685.y > 0.0f.xx.y));
                    bool _13802;
                    if (_13796)
                    {
                        _13802 = all(bool2(_19685.x < 1.0f.xx.x, _19685.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13802 = _13796;
                    }
                    _13729 = !_13802;
                }
                else
                {
                    _13729 = _13722;
                }
                if (_13729)
                {
                    _20831 = 0.0f;
                    break;
                }
                uint _13809_dummy_parameter;
                uint _13825_dummy_parameter;
                float4x4 _20830;
                do
                {
                    float4x4 _13839;
                    bool _20829;
                    do
                    {
                        _13839 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20829 = false;
                            break;
                        }
                        uint _13873 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_13873 + 32u) * 4 + 0) != 1u)
                        {
                            _20829 = false;
                            break;
                        }
                        uint _20826;
                        _20826 = 0u;
                        for (; _20826 < 4u; _20826++)
                        {
                            for (uint _20827 = 0u; _20827 < 4u; )
                            {
                                _13839[_20826][_20827] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13873 + 16u) + (_20826 * 4u)) + _20827) * 4 + 0));
                                _20827++;
                                continue;
                            }
                        }
                        _20829 = true;
                        break;
                    } while(false);
                    if (_20829)
                    {
                        _20830 = _13839;
                        break;
                    }
                    _20830 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13750 = mul(float4((float2(_19684.x, 1.0f - _19684.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19684 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13809_dummy_parameter))))), 0)).x, 1.0f), _20830);
                float _13752 = _13750.w;
                if (abs(_13752) < 9.9999999747524270787835121154785e-07f)
                {
                    _20831 = 0.0f;
                    break;
                }
                float _13763 = abs(cbFI_DeviceToViewDepth.y / ((_13750.z / _13752) - cbFI_DeviceToViewDepth.x));
                float _13766 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19685 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13825_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20831 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13763 - _13766) / max(max(_13763, _13766), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _13975 = all(bool2(_19685.x > 0.0f.xx.x, _19685.y > 0.0f.xx.y));
            bool _13981;
            if (_13975)
            {
                _13981 = all(bool2(_19685.x < 1.0f.xx.x, _19685.y < 1.0f.xx.y));
            }
            else
            {
                _13981 = _13975;
            }
            float _20832;
            if (_13981)
            {
                uint _13988_dummy_parameter;
                _20832 = length((_7809 + (r_motion_tp1.Load(int3(int2(floor(_19685 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _13988_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20832 = 1000000.0f;
            }
            float _20847;
            if ((_6682 & 1u) != 0u)
            {
                _20847 = _20831;
            }
            else
            {
                _20847 = 1.0f;
            }
            float _20848;
            if ((_6682 & 2u) != 0u)
            {
                _20848 = _20847 * (1.0f - smoothstep(2.0f, 8.0f, _20832));
            }
            else
            {
                _20848 = _20847;
            }
            float _20849;
            if ((_6682 & 4u) != 0u)
            {
                _20849 = _20848 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8530 - _8538) - length(_8514 - _8522))));
            }
            else
            {
                _20849 = _20848;
            }
            float _21179;
            if ((_6682 & 8u) != 0u)
            {
                _21179 = lerp(1.0f, _20849, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8514 - _8522)));
            }
            else
            {
                _21179 = _20849;
            }
            bool _6768 = (_6682 & 16u) != 0u;
            bool _6777;
            if (_6768)
            {
                _6777 = length(_19679 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6777 = _6768;
            }
            float _23579 = _6777 ? 1.0f : _21179;
            bool _6783 = _6688 && _10911;
            bool _6788;
            if (_6783)
            {
                bool _14013 = all(bool2(_19681.x > 0.0f.xx.x, _19681.y > 0.0f.xx.y));
                bool _14019;
                if (_14013)
                {
                    _14019 = all(bool2(_19681.x < 1.0f.xx.x, _19681.y < 1.0f.xx.y));
                }
                else
                {
                    _14019 = _14013;
                }
                _6788 = _14019;
            }
            else
            {
                _6788 = _6783;
            }
            bool _6793;
            if (_6788)
            {
                bool _14024 = all(bool2(_19683.x > 0.0f.xx.x, _19683.y > 0.0f.xx.y));
                bool _14030;
                if (_14024)
                {
                    _14030 = all(bool2(_19683.x < 1.0f.xx.x, _19683.y < 1.0f.xx.y));
                }
                else
                {
                    _14030 = _14024;
                }
                _6793 = _14030;
            }
            else
            {
                _6793 = _6788;
            }
            float4 _21186;
            if (_6793)
            {
                float _6799 = _21164.x + _21164.y;
                float _6808 = (_21164.z + _21164.w) * (1.0f - _23579);
                float _21182;
                if (_6799 > 9.9999997473787516355514526367188e-06f)
                {
                    _21182 = _21164.x / _6799;
                }
                else
                {
                    _21182 = _5538;
                }
                _21186 = float4(_21164.x + (_6808 * _21182), _21164.y + (_6808 * (1.0f - _21182)), _21164.zw * _23579);
            }
            else
            {
                _21186 = _21164;
            }
            _21185 = _21186;
        }
        else
        {
            _21185 = _21164;
        }
        float3 _6869 = (((_8514 * _21185.x) + (_8522 * _21185.y)) + (_8530 * _21185.z)) + (_8538 * _21185.w);
        float3 _22778;
        if (_5554 && (_21200 > 0.0f))
        {
            uint _14037_dummy_parameter;
            float2 _14052 = r_motion_tp1.Load(int3(int2(floor(_5313 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14037_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21462;
            if (_7837)
            {
                float2 _14097 = clamp((((_19658 + (_14052 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14100 = tan(_14097.x);
                _21462 = (float2(_14100 / cbFI_DeviceToViewDepth.z, (tan(_14097.y) * sqrt(1.0f + (_14100 * _14100))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21462 = _19658 + (_14052 * cbFI_Timestep);
            }
            float2 _21463;
            if (_7837)
            {
                float2 _14176 = clamp((((_19658 + (_14052 * _5528)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14179 = tan(_14176.x);
                _21463 = (float2(_14179 / cbFI_DeviceToViewDepth.z, (tan(_14176.y) * sqrt(1.0f + (_14179 * _14179))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21463 = _19658 + (_14052 * _5528);
            }
            _22778 = lerp(_6869, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21462, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21463, 0.0f).xyz, cbFI_Timestep.xxx), _21200.xxx);
        }
        else
        {
            _22778 = _6869;
        }
        float3 _22777;
        if (_21470)
        {
            float3 _14221 = r_current_interpolation_source.Load(int3(_4820, 0)).xyz;
            float3 _22779;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _10911)
            {
                uint _14228_dummy_parameter;
                float _21593;
                _21593 = r_depth_tm1.Load(int3(int2(floor(_19681 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14228_dummy_parameter))))), 0)).x;
                float _6950;
                for (int _21592 = 0; _21592 < 24; _21593 = _6950, _21592++)
                {
                    float _6922 = float(_21592 & 7) * 0.785398185253143310546875f;
                    int _6924 = _21592 >> 3;
                    int _23046;
                    if (_6924 == 0)
                    {
                        _23046 = 16;
                    }
                    else
                    {
                        _23046 = (_6924 == 1) ? 48 : 96;
                    }
                    uint _14248_dummy_parameter;
                    _6950 = min(_21593, r_depth_tm1.Load(int3(int2(floor(clamp(_19681 + ((cbFI_MvDepthLaneSizeRcp * float(_23046)) * float2(cos(_6922), sin(_6922))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14248_dummy_parameter))))), 0)).x);
                }
                float2 _21594;
                do
                {
                    float _14270 = 1.0f - _19681.y;
                    float4 _14281 = mul(float4((float2(_19681.x, _14270) * 2.0f) - 1.0f.xx, _21593, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14283 = _14281.w;
                    if (!(_14283 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21594 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14296 = ((_14281.xy / _14283.xx) + 1.0f.xx) * 0.5f;
                    _21594 = float2(_14296.x - _19681.x, _14270 - _14296.y);
                    break;
                } while(false);
                float2 _6961 = _19681 + _21594;
                bool _14314 = all(bool2(_6961.x > 0.0f.xx.x, _6961.y > 0.0f.xx.y));
                bool _14320;
                if (_14314)
                {
                    _14320 = all(bool2(_6961.x < 1.0f.xx.x, _6961.y < 1.0f.xx.y));
                }
                else
                {
                    _14320 = _14314;
                }
                float3 _22780;
                if (_14320)
                {
                    float _6967 = abs(cbFI_DeviceToViewDepth.y / (_21593 - cbFI_DeviceToViewDepth.x));
                    uint _14340_dummy_parameter;
                    int2 _14340 = int2(spvTextureSize(r_depth_m2, uint(0), _14340_dummy_parameter));
                    float _6971 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6961 * float2(_14340))), int2(0, 0), _14340 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22785;
                    if (abs(_6971 - _6967) <= (0.20000000298023223876953125f * max(_6971, _6967)))
                    {
                        uint _14374_dummy_parameter;
                        int2 _14374 = int2(spvTextureSize(r_colour_m2, uint(0), _14374_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14397;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14397);
                        }
                        _22785 = r_colour_m2.Load(int3(clamp(int2(floor(_6961 * float2(_14374))), int2(0, 0), _14374 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14407;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14407);
                        }
                        _22785 = _14221;
                    }
                    _22780 = _22785;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14417;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14417);
                    }
                    _22780 = _14221;
                }
                _22779 = _22780;
            }
            else
            {
                _22779 = _14221;
            }
            _22777 = _22779;
        }
        else
        {
            _22777 = _22778;
        }
        bool _6996 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22776;
        float _22852;
        if (_6996)
        {
            bool _14632;
            float2 _7000 = float2(cbFI_DisplaySize);
            float4x4 _21601;
            do
            {
                float4x4 _14608;
                bool _21600;
                do
                {
                    _14608 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                    _14632 = (cbFI_NfruT2Flags & 524288u) == 0u;
                    if (_14632)
                    {
                        _21600 = false;
                        break;
                    }
                    uint _14642 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                    if (rw_nfru_diagnostics.Load<uint>((_14642 + 32u) * 4 + 0) != 1u)
                    {
                        _21600 = false;
                        break;
                    }
                    uint _21597;
                    _21597 = 0u;
                    for (; _21597 < 4u; _21597++)
                    {
                        for (uint _21598 = 0u; _21598 < 4u; )
                        {
                            _14608[_21597][_21598] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14642 + (_21597 * 4u)) + _21598) * 4 + 0));
                            _21598++;
                            continue;
                        }
                    }
                    _21600 = true;
                    break;
                } while(false);
                if (_21600)
                {
                    _21601 = _14608;
                    break;
                }
                _21601 = cbFI_MotionTP1ToTM1;
                break;
            } while(false);
            float _14719;
            float _14722;
            float4 _14732;
            float2 _21602;
            do
            {
                _14719 = _5313.x;
                _14722 = 1.0f - _5313.y;
                _14732 = float4((float2(_14719, _14722) * 2.0f) - 1.0f.xx, 1.0000000116860974230803549289703e-07f, 1.0f);
                float4 _14733 = mul(_14732, _21601);
                float _14735 = _14733.w;
                if (!(_14735 > 9.9999999747524270787835121154785e-07f))
                {
                    _21602 = 1000000.0f.xx;
                    break;
                }
                float2 _14748 = ((_14733.xy / _14735.xx) + 1.0f.xx) * 0.5f;
                _21602 = float2(_14748.x - _14719, _14722 - _14748.y);
                break;
            } while(false);
            float4x4 _21607;
            do
            {
                float4x4 _14766;
                bool _21606;
                do
                {
                    _14766 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                    if (_14632)
                    {
                        _21606 = false;
                        break;
                    }
                    uint _14800 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                    if (rw_nfru_diagnostics.Load<uint>((_14800 + 32u) * 4 + 0) != 1u)
                    {
                        _21606 = false;
                        break;
                    }
                    uint _21603;
                    _21603 = 0u;
                    for (; _21603 < 4u; _21603++)
                    {
                        for (uint _21604 = 0u; _21604 < 4u; )
                        {
                            _14766[_21603][_21604] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14800 + 16u) + (_21603 * 4u)) + _21604) * 4 + 0));
                            _21604++;
                            continue;
                        }
                    }
                    _21606 = true;
                    break;
                } while(false);
                if (_21606)
                {
                    _21607 = _14766;
                    break;
                }
                _21607 = cbFI_MotionTM1ToTP1;
                break;
            } while(false);
            float2 _21608;
            do
            {
                float4 _14891 = mul(_14732, _21607);
                float _14893 = _14891.w;
                if (!(_14893 > 9.9999999747524270787835121154785e-07f))
                {
                    _21608 = 1000000.0f.xx;
                    break;
                }
                float2 _14906 = ((_14891.xy / _14893.xx) + 1.0f.xx) * 0.5f;
                _21608 = float2(_14906.x - _14719, _14722 - _14906.y);
                break;
            } while(false);
            float2 _14469 = abs(_21602);
            bool2 _23580 = any(bool2(_14469.x > 4.0f.xx.x, _14469.y > 4.0f.xx.y)).xx;
            float2 _14475 = abs(_21608);
            bool2 _23582 = any(bool2(_14475.x > 4.0f.xx.x, _14475.y > 4.0f.xx.y)).xx;
            float2 _14920[3];
            _14920[0] = _5313;
            float2 _15036 = clamp(_5313, 0.0f.xx, 1.0f.xx);
            uint _15044_dummy_parameter;
            _14920[1] = _5313 - ((r_motion_tp1.Load(int3(int2(floor(_15036 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15044_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5538);
            _14920[2] = _5313 - (float2(_23580.x ? 0.0f.xx.x : _21602.x, _23580.y ? 0.0f.xx.y : _21602.y) * _5538);
            float _21618;
            float2 _21619;
            _21619 = _5313;
            _21618 = 1000000000.0f;
            float _23584;
            float2 _23586;
            float _23587;
            int _21617 = 0;
            float _23038 = -1.0f;
            for (; _21617 < 3; _23038 = _23584, _21619 = _23586, _21618 = _23587, _21617++)
            {
                float2 _23028;
                _23028 = _14920[_21617];
                for (int _23027 = 0; _23027 < 30; )
                {
                    uint _15660_dummy_parameter;
                    _23028 += (((_5313 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_23028, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15660_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5538)) - _23028) * 0.699999988079071044921875f);
                    _23027++;
                    continue;
                }
                float2 _16196 = clamp(_23028, 0.0f.xx, 1.0f.xx);
                uint _16204_dummy_parameter;
                bool _16740 = all(bool2(_23028.x > 0.0f.xx.x, _23028.y > 0.0f.xx.y));
                bool _16746;
                if (_16740)
                {
                    _16746 = all(bool2(_23028.x < 1.0f.xx.x, _23028.y < 1.0f.xx.y));
                }
                else
                {
                    _16746 = _16740;
                }
                float _23030;
                if (_16746)
                {
                    _23030 = length(((_23028 + ((r_motion_tp1.Load(int3(int2(floor(_16196 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16204_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5538)) - _5313) * float2(cbFI_RenderSize));
                }
                else
                {
                    _23030 = 1000000000.0f;
                }
                uint _16757_dummy_parameter;
                float _16797 = log((r_depth_tp1.Load(int3(int2(floor(_16196 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16757_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _14996 = _23030 < 0.3499999940395355224609375f;
                bool _14998 = _21618 < 0.3499999940395355224609375f;
                bool _15008;
                if (_14996)
                {
                    _15008 = (!_14998) || (_16797 > _23038);
                }
                else
                {
                    _15008 = _14996;
                }
                bool _15021;
                if (!_15008)
                {
                    _15021 = ((!_14996) && (!_14998)) && (_23030 < _21618);
                }
                else
                {
                    _15021 = _15008;
                }
                _23584 = _15021 ? _16797 : _23038;
                bool2 _23585 = _15021.xx;
                _23586 = float2(_23585.x ? _23028.x : _21619.x, _23585.y ? _23028.y : _21619.y);
                _23587 = _15021 ? _23030 : _21618;
            }
            float2 _16799[3];
            _16799[0] = _5313;
            float2 _21647;
            do
            {
                bool _21628;
                do
                {
                    bool _17042 = all(bool2(_15036.x > 0.0f.xx.x, _15036.y > 0.0f.xx.y));
                    bool _17048;
                    if (_17042)
                    {
                        _17048 = all(bool2(_15036.x < 1.0f.xx.x, _15036.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17048 = _17042;
                    }
                    if (!_17048)
                    {
                        _21628 = false;
                        break;
                    }
                    uint _17055_dummy_parameter;
                    float4x4 _21626;
                    do
                    {
                        float4x4 _17069;
                        bool _21625;
                        do
                        {
                            _17069 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14632)
                            {
                                _21625 = false;
                                break;
                            }
                            uint _17103 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_17103 + 32u) * 4 + 0) != 1u)
                            {
                                _21625 = false;
                                break;
                            }
                            uint _21622;
                            _21622 = 0u;
                            for (; _21622 < 4u; _21622++)
                            {
                                for (uint _21623 = 0u; _21623 < 4u; )
                                {
                                    _17069[_21622][_21623] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17103 + (_21622 * 4u)) + _21623) * 4 + 0));
                                    _21623++;
                                    continue;
                                }
                            }
                            _21625 = true;
                            break;
                        } while(false);
                        if (_21625)
                        {
                            _21626 = _17069;
                            break;
                        }
                        _21626 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _21627;
                    do
                    {
                        float _17180 = _15036.x;
                        float _17183 = 1.0f - _15036.y;
                        float4 _17194 = mul(float4((float2(_17180, _17183) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15036 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17055_dummy_parameter))))), 0)).x, 1.0f), _21626);
                        float _17196 = _17194.w;
                        if (!(_17196 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21627 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17209 = ((_17194.xy / _17196.xx) + 1.0f.xx) * 0.5f;
                        _21627 = float2(_17209.x - _17180, _17183 - _17209.y);
                        break;
                    } while(false);
                    float2 _17006 = abs(_21627);
                    if (any(bool2(_17006.x > 100000.0f.xx.x, _17006.y > 100000.0f.xx.y)))
                    {
                        _21628 = false;
                        break;
                    }
                    float _17014 = length(_21627 * _7000);
                    uint _17229_dummy_parameter;
                    bool _17028 = _17014 > ((8.0f * _7000.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _17035;
                    if (_17028)
                    {
                        _17035 = length((r_motion_tp1.Load(int3(int2(floor(_15036 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17229_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7000) < (0.20000000298023223876953125f * _17014);
                    }
                    else
                    {
                        _17035 = _17028;
                    }
                    _21628 = _17035;
                    break;
                } while(false);
                if (_21628)
                {
                    uint _17260_dummy_parameter;
                    _21647 = -(r_motion_tp1.Load(int3(int2(floor(_15036 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17260_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                    break;
                }
                uint _17287_dummy_parameter;
                float4x4 _21641;
                do
                {
                    float4x4 _17301;
                    bool _21640;
                    do
                    {
                        _17301 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_14632)
                        {
                            _21640 = false;
                            break;
                        }
                        uint _17335 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_17335 + 32u) * 4 + 0) != 1u)
                        {
                            _21640 = false;
                            break;
                        }
                        uint _21637;
                        _21637 = 0u;
                        for (; _21637 < 4u; _21637++)
                        {
                            for (uint _21638 = 0u; _21638 < 4u; )
                            {
                                _17301[_21637][_21638] = asfloat(rw_nfru_diagnostics.Load<uint>((((_17335 + 16u) + (_21637 * 4u)) + _21638) * 4 + 0));
                                _21638++;
                                continue;
                            }
                        }
                        _21640 = true;
                        break;
                    } while(false);
                    if (_21640)
                    {
                        _21641 = _17301;
                        break;
                    }
                    _21641 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float2 _21646;
                do
                {
                    float _17412 = _15036.x;
                    float _17415 = 1.0f - _15036.y;
                    float4 _17426 = mul(float4((float2(_17412, _17415) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15036 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17287_dummy_parameter))))), 0)).x, 1.0f), _21641);
                    float _17428 = _17426.w;
                    if (!(_17428 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21646 = 1000000.0f.xx;
                        break;
                    }
                    float2 _17441 = ((_17426.xy / _17428.xx) + 1.0f.xx) * 0.5f;
                    _21646 = float2(_17441.x - _17412, _17415 - _17441.y);
                    break;
                } while(false);
                float2 _16973 = abs(_21646);
                bool2 _16977 = any(bool2(_16973.x > 4.0f.xx.x, _16973.y > 4.0f.xx.y)).xx;
                _21647 = float2(_16977.x ? 0.0f.xx.x : _21646.x, _16977.y ? 0.0f.xx.y : _21646.y);
                break;
            } while(false);
            _16799[1] = _5313 - (_21647 * cbFI_Timestep);
            _16799[2] = _5313 - (float2(_23582.x ? 0.0f.xx.x : _21608.x, _23582.y ? 0.0f.xx.y : _21608.y) * cbFI_Timestep);
            float _21649;
            float2 _21650;
            _21650 = _5313;
            _21649 = 1000000000.0f;
            float _23588;
            float2 _23590;
            float _23591;
            float4x4 _17685;
            float4x4 _17917;
            float4x4 _18229;
            float4x4 _18461;
            int _21648 = 0;
            float _22940 = -1.0f;
            for (; _21648 < 3; _22940 = _23588, _21650 = _23590, _21649 = _23591, _21648++)
            {
                float2 _22873;
                _22873 = _16799[_21648];
                float2 _17495;
                for (int _22872 = 0; _22872 < 30; _22873 = _17495, _22872++)
                {
                    float2 _22998;
                    do
                    {
                        float2 _17574 = clamp(_22873, 0.0f.xx, 1.0f.xx);
                        bool _22979;
                        do
                        {
                            bool _17658 = all(bool2(_17574.x > 0.0f.xx.x, _17574.y > 0.0f.xx.y));
                            bool _17664;
                            if (_17658)
                            {
                                _17664 = all(bool2(_17574.x < 1.0f.xx.x, _17574.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _17664 = _17658;
                            }
                            if (!_17664)
                            {
                                _22979 = false;
                                break;
                            }
                            uint _17671_dummy_parameter;
                            float4x4 _22977;
                            do
                            {
                                bool _22976;
                                do
                                {
                                    _17685 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14632)
                                    {
                                        _22976 = false;
                                        break;
                                    }
                                    uint _17719 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_17719 + 32u) * 4 + 0) != 1u)
                                    {
                                        _22976 = false;
                                        break;
                                    }
                                    uint _22973;
                                    _22973 = 0u;
                                    for (; _22973 < 4u; _22973++)
                                    {
                                        for (uint _22974 = 0u; _22974 < 4u; )
                                        {
                                            _17685[_22973][_22974] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17719 + (_22973 * 4u)) + _22974) * 4 + 0));
                                            _22974++;
                                            continue;
                                        }
                                    }
                                    _22976 = true;
                                    break;
                                } while(false);
                                if (_22976)
                                {
                                    _22977 = _17685;
                                    break;
                                }
                                _22977 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _22978;
                            do
                            {
                                float _17796 = _17574.x;
                                float _17799 = 1.0f - _17574.y;
                                float4 _17810 = mul(float4((float2(_17796, _17799) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17574 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17671_dummy_parameter))))), 0)).x, 1.0f), _22977);
                                float _17812 = _17810.w;
                                if (!(_17812 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22978 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17825 = ((_17810.xy / _17812.xx) + 1.0f.xx) * 0.5f;
                                _22978 = float2(_17825.x - _17796, _17799 - _17825.y);
                                break;
                            } while(false);
                            float2 _17622 = abs(_22978);
                            if (any(bool2(_17622.x > 100000.0f.xx.x, _17622.y > 100000.0f.xx.y)))
                            {
                                _22979 = false;
                                break;
                            }
                            float _17630 = length(_22978 * _7000);
                            uint _17845_dummy_parameter;
                            bool _17644 = _17630 > ((8.0f * _7000.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _17651;
                            if (_17644)
                            {
                                _17651 = length((r_motion_tp1.Load(int3(int2(floor(_17574 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17845_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7000) < (0.20000000298023223876953125f * _17630);
                            }
                            else
                            {
                                _17651 = _17644;
                            }
                            _22979 = _17651;
                            break;
                        } while(false);
                        if (_22979)
                        {
                            uint _17876_dummy_parameter;
                            _22998 = -(r_motion_tp1.Load(int3(int2(floor(_17574 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17876_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _17903_dummy_parameter;
                        float4x4 _22992;
                        do
                        {
                            bool _22991;
                            do
                            {
                                _17917 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14632)
                                {
                                    _22991 = false;
                                    break;
                                }
                                uint _17951 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17951 + 32u) * 4 + 0) != 1u)
                                {
                                    _22991 = false;
                                    break;
                                }
                                uint _22988;
                                _22988 = 0u;
                                for (; _22988 < 4u; _22988++)
                                {
                                    for (uint _22989 = 0u; _22989 < 4u; )
                                    {
                                        _17917[_22988][_22989] = asfloat(rw_nfru_diagnostics.Load<uint>((((_17951 + 16u) + (_22988 * 4u)) + _22989) * 4 + 0));
                                        _22989++;
                                        continue;
                                    }
                                }
                                _22991 = true;
                                break;
                            } while(false);
                            if (_22991)
                            {
                                _22992 = _17917;
                                break;
                            }
                            _22992 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float2 _22997;
                        do
                        {
                            float _18028 = _17574.x;
                            float _18031 = 1.0f - _17574.y;
                            float4 _18042 = mul(float4((float2(_18028, _18031) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17574 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17903_dummy_parameter))))), 0)).x, 1.0f), _22992);
                            float _18044 = _18042.w;
                            if (!(_18044 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22997 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18057 = ((_18042.xy / _18044.xx) + 1.0f.xx) * 0.5f;
                            _22997 = float2(_18057.x - _18028, _18031 - _18057.y);
                            break;
                        } while(false);
                        float2 _17589 = abs(_22997);
                        bool2 _17593 = any(bool2(_17589.x > 4.0f.xx.x, _17589.y > 4.0f.xx.y)).xx;
                        _22998 = float2(_17593.x ? 0.0f.xx.x : _22997.x, _17593.y ? 0.0f.xx.y : _22997.y);
                        break;
                    } while(false);
                    _17495 = _22873 + (((_5313 - (_22998 * cbFI_Timestep)) - _22873) * 0.699999988079071044921875f);
                }
                float2 _18118;
                float2 _22899;
                do
                {
                    _18118 = clamp(_22873, 0.0f.xx, 1.0f.xx);
                    bool _22880;
                    do
                    {
                        bool _18202 = all(bool2(_18118.x > 0.0f.xx.x, _18118.y > 0.0f.xx.y));
                        bool _18208;
                        if (_18202)
                        {
                            _18208 = all(bool2(_18118.x < 1.0f.xx.x, _18118.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _18208 = _18202;
                        }
                        if (!_18208)
                        {
                            _22880 = false;
                            break;
                        }
                        uint _18215_dummy_parameter;
                        float4x4 _22878;
                        do
                        {
                            bool _22877;
                            do
                            {
                                _18229 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14632)
                                {
                                    _22877 = false;
                                    break;
                                }
                                uint _18263 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_18263 + 32u) * 4 + 0) != 1u)
                                {
                                    _22877 = false;
                                    break;
                                }
                                uint _22874;
                                _22874 = 0u;
                                for (; _22874 < 4u; _22874++)
                                {
                                    for (uint _22875 = 0u; _22875 < 4u; )
                                    {
                                        _18229[_22874][_22875] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18263 + (_22874 * 4u)) + _22875) * 4 + 0));
                                        _22875++;
                                        continue;
                                    }
                                }
                                _22877 = true;
                                break;
                            } while(false);
                            if (_22877)
                            {
                                _22878 = _18229;
                                break;
                            }
                            _22878 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _22879;
                        do
                        {
                            float _18343 = 1.0f - _18118.y;
                            float4 _18354 = mul(float4((float2(_18118.x, _18343) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18118 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18215_dummy_parameter))))), 0)).x, 1.0f), _22878);
                            float _18356 = _18354.w;
                            if (!(_18356 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22879 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18369 = ((_18354.xy / _18356.xx) + 1.0f.xx) * 0.5f;
                            _22879 = float2(_18369.x - _18118.x, _18343 - _18369.y);
                            break;
                        } while(false);
                        float2 _18166 = abs(_22879);
                        if (any(bool2(_18166.x > 100000.0f.xx.x, _18166.y > 100000.0f.xx.y)))
                        {
                            _22880 = false;
                            break;
                        }
                        float _18174 = length(_22879 * _7000);
                        uint _18389_dummy_parameter;
                        bool _18188 = _18174 > ((8.0f * _7000.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _18195;
                        if (_18188)
                        {
                            _18195 = length((r_motion_tp1.Load(int3(int2(floor(_18118 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18389_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7000) < (0.20000000298023223876953125f * _18174);
                        }
                        else
                        {
                            _18195 = _18188;
                        }
                        _22880 = _18195;
                        break;
                    } while(false);
                    if (_22880)
                    {
                        uint _18420_dummy_parameter;
                        _22899 = -(r_motion_tp1.Load(int3(int2(floor(_18118 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18420_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _18447_dummy_parameter;
                    float4x4 _22893;
                    do
                    {
                        bool _22892;
                        do
                        {
                            _18461 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14632)
                            {
                                _22892 = false;
                                break;
                            }
                            uint _18495 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_18495 + 32u) * 4 + 0) != 1u)
                            {
                                _22892 = false;
                                break;
                            }
                            uint _22889;
                            _22889 = 0u;
                            for (; _22889 < 4u; _22889++)
                            {
                                for (uint _22890 = 0u; _22890 < 4u; )
                                {
                                    _18461[_22889][_22890] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18495 + 16u) + (_22889 * 4u)) + _22890) * 4 + 0));
                                    _22890++;
                                    continue;
                                }
                            }
                            _22892 = true;
                            break;
                        } while(false);
                        if (_22892)
                        {
                            _22893 = _18461;
                            break;
                        }
                        _22893 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _22898;
                    do
                    {
                        float _18575 = 1.0f - _18118.y;
                        float4 _18586 = mul(float4((float2(_18118.x, _18575) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18118 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18447_dummy_parameter))))), 0)).x, 1.0f), _22893);
                        float _18588 = _18586.w;
                        if (!(_18588 > 9.9999999747524270787835121154785e-07f))
                        {
                            _22898 = 1000000.0f.xx;
                            break;
                        }
                        float2 _18601 = ((_18586.xy / _18588.xx) + 1.0f.xx) * 0.5f;
                        _22898 = float2(_18601.x - _18118.x, _18575 - _18601.y);
                        break;
                    } while(false);
                    float2 _18133 = abs(_22898);
                    bool2 _18137 = any(bool2(_18133.x > 4.0f.xx.x, _18133.y > 4.0f.xx.y)).xx;
                    _22899 = float2(_18137.x ? 0.0f.xx.x : _22898.x, _18137.y ? 0.0f.xx.y : _22898.y);
                    break;
                } while(false);
                bool _18619 = all(bool2(_22873.x > 0.0f.xx.x, _22873.y > 0.0f.xx.y));
                bool _18625;
                if (_18619)
                {
                    _18625 = all(bool2(_22873.x < 1.0f.xx.x, _22873.y < 1.0f.xx.y));
                }
                else
                {
                    _18625 = _18619;
                }
                float _22915;
                if (_18625)
                {
                    _22915 = length(((_22873 + (_22899 * cbFI_Timestep)) - _5313) * float2(cbFI_RenderSize));
                }
                else
                {
                    _22915 = 1000000000.0f;
                }
                uint _18652_dummy_parameter;
                float _18676 = log((r_depth_tm1.Load(int3(int2(floor(_18118 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18652_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _16875 = _22915 < 0.3499999940395355224609375f;
                bool _16877 = _21649 < 0.3499999940395355224609375f;
                bool _16887;
                if (_16875)
                {
                    _16887 = (!_16877) || (_18676 > _22940);
                }
                else
                {
                    _16887 = _16875;
                }
                bool _16900;
                if (!_16887)
                {
                    _16900 = ((!_16875) && (!_16877)) && (_22915 < _21649);
                }
                else
                {
                    _16900 = _16887;
                }
                _23588 = _16900 ? _18676 : _22940;
                bool2 _23589 = _16900.xx;
                _23590 = float2(_23589.x ? _22873.x : _21650.x, _23589.y ? _22873.y : _21650.y);
                _23591 = _16900 ? _22915 : _21649;
            }
            float3 _18685 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21619, 0.0f).xyz;
            float3 _18693 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21650, 0.0f).xyz;
            uint _18700_dummy_parameter;
            uint _18731_dummy_parameter;
            float _14513 = exp((_21618 * (-2.0f)) * (_21618 * 2.0f));
            float _14520 = exp((_21649 * (-2.0f)) * (_21649 * 2.0f));
            float _14533 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21650, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18731_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21619, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18700_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
            float _14547 = ((_14513 * cbFI_Timestep) * ((1.0f - _14520) + ((_14520 * 2.0f) * _14533))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
            float _14557 = 1.0f - _14533;
            float _14564 = ((_14520 * _5538) * ((1.0f - _14513) + ((_14513 * 2.0f) * _14557))) + (9.9999997473787516355514526367188e-05f * _5538);
            float _14573 = (((_14513 * _14520) * 4.0f) * _14533) * _14557;
            _22852 = (_14573 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18693 - _18685, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14573)) * max(_14513, _14520));
            _22776 = ((_18685 * _14547) + (_18693 * _14564)) / (_14547 + _14564).xxx;
        }
        else
        {
            _22852 = 1.0f;
            _22776 = _22777;
        }
        uint _7012 = cbFI_pad0 & 255u;
        bool _22621;
        float3 _22775;
        if (_7012 != 0u)
        {
            float3 _7017 = r_present_backbuffer.Load(int3(_4820, 0)).xyz;
            float3 _7021 = r_current_interpolation_source.Load(int3(_4820, 0)).xyz;
            float3 _7025 = abs(_7017 - _7021);
            float3 _21651;
            if (_7012 == 2u)
            {
                _21651 = (abs(_7021) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21651 = 0.000244140625f.xxx;
            }
            bool _7041 = any(bool3(_7025.x > _21651.x, _7025.y > _21651.y, _7025.z > _21651.z));
            bool3 _23592 = _7041.xxx;
            _22775 = float3(_23592.x ? _7017.x : _22776.x, _23592.y ? _7017.y : _22776.y, _23592.z ? _7017.z : _22776.z);
            _22621 = _7041;
        }
        else
        {
            _22775 = _22776;
            _22621 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18769;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18769);
        }
        float3 _22757;
        if (_6686 == 1u)
        {
            _22757 = lerp(_8514, _8522, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22758;
            if (_6686 == 2u)
            {
                _22758 = lerp(_8530, _8538, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22759;
                if (_6686 == 3u)
                {
                    _22759 = float(_22621).xxx;
                }
                else
                {
                    float3 _22760;
                    if (_6686 == 4u)
                    {
                        _22760 = float3(((_19679 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22761;
                        if (_6686 == 5u)
                        {
                            _22761 = float3(((_7809 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22762;
                            if (_6686 == 6u)
                            {
                                _22762 = float3(_21185.xy, _21185.z + _21185.w);
                            }
                            else
                            {
                                float3 _22763;
                                if (_6686 == 7u)
                                {
                                    _22763 = r_current_interpolation_source.Load(int3(_4820, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22764;
                                    if (_6686 == 8u)
                                    {
                                        _22764 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5313, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22765;
                                        if (_6690)
                                        {
                                            uint _18791_dummy_parameter;
                                            uint _18823_dummy_parameter;
                                            _22765 = float3(log((r_depth_tp1.Load(int3(int2(floor(_5313 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18791_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_5313 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18823_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22766;
                                            if (_6693)
                                            {
                                                _22766 = _8530;
                                            }
                                            else
                                            {
                                                float3 _22767;
                                                if (_6686 == 20u)
                                                {
                                                    _22767 = _8514;
                                                }
                                                else
                                                {
                                                    float3 _22768;
                                                    if (_6686 == 21u)
                                                    {
                                                        _22768 = _8522;
                                                    }
                                                    else
                                                    {
                                                        float3 _22769;
                                                        if (_6686 == 22u)
                                                        {
                                                            _22769 = _8538;
                                                        }
                                                        else
                                                        {
                                                            float3 _22770;
                                                            if (_6686 == 18u)
                                                            {
                                                                _22770 = _22183;
                                                            }
                                                            else
                                                            {
                                                                float3 _22771;
                                                                if (_6686 == 19u)
                                                                {
                                                                    _22771 = _21918;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22772;
                                                                    if (_6686 == 23u)
                                                                    {
                                                                        _22772 = _21659;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22773;
                                                                        if (_6686 == 24u)
                                                                        {
                                                                            uint _7185 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7190 = float(rw_nfru_diagnostics.Load<uint>((_7185 + 35u) * 4 + 0));
                                                                            float _21652;
                                                                            if (_7190 > 0.0f)
                                                                            {
                                                                                _21652 = float(rw_nfru_diagnostics.Load<uint>((_7185 + 34u) * 4 + 0)) / _7190;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21652 = 0.0f;
                                                                            }
                                                                            _22773 = float3(float(rw_nfru_diagnostics.Load<uint>((_7185 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7185 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21652);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22773 = _22775;
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
                                            _22765 = _22766;
                                        }
                                        _22764 = _22765;
                                    }
                                    _22763 = _22764;
                                }
                                _22762 = _22763;
                            }
                            _22761 = _22762;
                        }
                        _22760 = _22761;
                    }
                    _22759 = _22760;
                }
                _22758 = _22759;
            }
            _22757 = _22758;
        }
        float3 _22756;
        if ((_6686 >= 9u) && (_6686 <= 11u))
        {
            uint _7250 = 64u + uint((_19902.y * cbFI_MvDepthLaneSize.x) + _19902.x);
            uint _7254 = rw_nfru_diagnostics.Load<uint>(_7250 * 4 + 0) & 15u;
            float3 _22790;
            if (_6686 == 10u)
            {
                float3 _22755;
                if ((rw_nfru_diagnostics.Load<uint>(_7250 * 4 + 0) & 32u) != 0u)
                {
                    _22755 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22754;
                    if ((rw_nfru_diagnostics.Load<uint>(_7250 * 4 + 0) & 16u) != 0u)
                    {
                        _22754 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7275 = ((rw_nfru_diagnostics.Load<uint>(_7250 * 4 + 0) & 64u) != 0u).xxx;
                        _22754 = float3(_7275.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7275.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7275.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22755 = _22754;
                }
                _22790 = _22755;
            }
            else
            {
                float3 _22791;
                if (_6686 == 11u)
                {
                    uint _7288 = (rw_nfru_diagnostics.Load<uint>(_7250 * 4 + 0) >> 8u) & 15u;
                    uint _7291 = (rw_nfru_diagnostics.Load<uint>(_7250 * 4 + 0) >> 12u) & 15u;
                    float3 _22747;
                    if ((_7254 == 2u) || (_7254 == 3u))
                    {
                        _22747 = _4519[_7254];
                    }
                    else
                    {
                        bool _7303 = _7288 == 3u;
                        bool _7305 = _7291 == 3u;
                        float3 _22748;
                        if (_7303 && _7305)
                        {
                            _22748 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22749;
                            if (_7303)
                            {
                                _22749 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22750;
                                if (_7305)
                                {
                                    _22750 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22751;
                                    if ((_7288 == 4u) || (_7291 == 4u))
                                    {
                                        _22751 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22752;
                                        if ((_7288 == 1u) || (_7291 == 1u))
                                        {
                                            _22752 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23594 = (_7254 == 1u).xxx;
                                            _22752 = float3(_23594.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23594.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23594.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22751 = _22752;
                                    }
                                    _22750 = _22751;
                                }
                                _22749 = _22750;
                            }
                            _22748 = _22749;
                        }
                        _22747 = _22748;
                    }
                    _22791 = _22747;
                }
                else
                {
                    _22791 = _4519[min(_7254, 7u)];
                }
                _22790 = _22791;
            }
            _22756 = _22790;
        }
        else
        {
            _22756 = _22757;
        }
        float4 _22794;
        if ((_6686 >= 14u) && (_6686 <= 16u))
        {
            float2 _22792;
            if (_6686 == 14u)
            {
                uint _7361_dummy_parameter;
                uint _7367_dummy_parameter;
                _22792 = r_flow_tm1.Load(int3(clamp(int2(floor(_5313 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7361_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7367_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22793;
                if (_6686 == 16u)
                {
                    uint _18899 = r_warped_flow_qdata_tm1.Load(int3(_5329, 0)).x & 2147483647u;
                    uint _18931 = uint(max((int((_18899 >> 16u) & 15u) - 6), 0));
                    _22793 = ((float2(float((1 - (2 * int((_18899 >> 15u) & 1u))) * int(((_18899 >> uint(7)) & 127u) << _18931)), float((1 - (2 * int((_18899 >> 14u) & 1u))) * int((_18899 & 127u) << _18931))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22793 = _7809 * float2(cbFI_DisplaySize);
                }
                _22792 = _22793;
            }
            uint2 _7400 = uint2(clamp(round(_22792 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7402 = _7400.x;
            uint _7409 = _7400.y;
            _22794 = float4(float(_7402 & 255u), float((_7402 >> 8u) | ((_7409 & 15u) << 4u)), float(_7409 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22795;
            if (_6686 == 17u)
            {
                _22795 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5329, 0)).x != 0u), _5773, 0.0f, 1.0f);
            }
            else
            {
                _22795 = float4(_22756, 1.0f);
            }
            _22794 = _22795;
        }
        rw_output[_4820] = _22794.xyz;
        if (_6996)
        {
            uint _18976 = uint((_4820.y * cbFI_DisplaySize.x) + _4820.x) * 2u;
            rw_nfru_select.Store<uint>(_18976 * 4 + 0, spvPackHalf2x16(_22794.xy));
            rw_nfru_select.Store<uint>((_18976 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22794.z, (_22621 || (_6686 != 0u)) ? 2.0f : _22852)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7467 = ((uint(_4820.y) * uint(cbFI_DisplaySize.x)) + uint(_4820.x)) * 6u;
            uint _19002 = spvPackHalf2x16(clamp(_8513.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7467 * 4 + 0, (((_19002 & 32767u) >> 4u) | ((((_19002 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8513.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19037 = spvPackHalf2x16(clamp(_8521.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7467 + 1u) * 4 + 0, (((_19037 & 32767u) >> 4u) | ((((_19037 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8521.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19072 = spvPackHalf2x16(clamp(_8529.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7467 + 2u) * 4 + 0, (((_19072 & 32767u) >> 4u) | ((((_19072 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8529.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19107 = spvPackHalf2x16(clamp(_8537.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7467 + 3u) * 4 + 0, (((_19107 & 32767u) >> 4u) | ((((_19107 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8537.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19134 = r_current_interpolation_source.Load(int3(_4820, 0));
            uint _19148 = spvPackHalf2x16(clamp(_19134.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7467 + 4u) * 4 + 0, (((_19148 & 32767u) >> 4u) | ((((_19148 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19134.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _22871;
            if (_22621 || (_6686 != 0u))
            {
                _22871 = 4294967295u;
            }
            else
            {
                uint _19183 = spvPackHalf2x16(clamp(_22794.xy, 0.0f.xx, 65000.0f.xx));
                _22871 = (((_19183 & 32767u) >> 4u) | ((((_19183 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22794.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7467 + 5u) * 4 + 0, _22871);
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
