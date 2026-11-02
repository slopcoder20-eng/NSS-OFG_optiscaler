static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3013[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3300 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3300.x >= cbFI_DisplaySize.x, _3300.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3300] = float4(r_present_backbuffer.Load(int3(_3300, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3650 = (float2(_3300) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3661 = int2(floor(_3650 * float2(cbFI_MvDepthLaneSize)));
        int2 _3666 = int2(floor(_3650 * float2(cbFI_FlowLaneSize)));
        float4 _5327 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3650 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5333 = r_warped_filled_flow_tm1.Load(int3(_3666, 0)).xy;
        float2 _5339 = r_warped_filled_motion_tp1.Load(int3(_3661, 0)).xy;
        bool _5361 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8751;
        if (_5361)
        {
            float _5374 = ((2.0f * _3650.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8751 = float2(atan(_5374) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3650.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5374 * _5374))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8751 = _3650;
        }
        bool _3687 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8772;
        bool _8793;
        int2 _8804;
        float3 _9695;
        if (_3687)
        {
            float _8753;
            float _8755;
            _8755 = 2.0f;
            _8753 = -1.0f;
            uint _3362[9];
            float _10079;
            float _10082;
            for (int _8752 = 0; _8752 < 9; _8755 = _10082, _8753 = _10079, _8752++)
            {
                _3362[_8752] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3661 + int2((_8752 % 3) - 1, (_8752 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3362[_8752] != 0u)
                {
                    float _10074;
                    if (_3362[_8752] == 0u)
                    {
                        _10074 = -1.0f;
                    }
                    else
                    {
                        _10074 = float((_3362[_8752] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10082 = min(_8755, _10074);
                    _10079 = max(_8753, _10074);
                }
                else
                {
                    _10082 = _8755;
                    _10079 = _8753;
                }
            }
            float _3733 = float(_8753 >= 0.0f);
            float3 _8566 = 0.0f.xxx;
            _8566.y = _3733;
            float2 _8773;
            bool _8794;
            int2 _8805;
            float3 _9696;
            if ((_8753 - _8755) > 0.0199999995529651641845703125f)
            {
                float _8761;
                int2 _8762;
                float2 _8763;
                int2 _8765;
                float2 _8771;
                _8771 = _5339;
                _8765 = _3661;
                _8763 = _5339;
                _8762 = _3661;
                _8761 = -1.0f;
                float _10087;
                int2 _10091;
                float2 _10102;
                int2 _10113;
                float2 _10146;
                float _10191;
                int _8760 = 0;
                float _10055 = 1000000000.0f;
                for (; _8760 < 9; _10055 = _10191, _8771 = _10146, _8765 = _10113, _8763 = _10102, _8762 = _10091, _8761 = _10087, _8760++)
                {
                    if (_3362[_8760] == 0u)
                    {
                        _10191 = _10055;
                        _10146 = _8771;
                        _10113 = _8765;
                        _10102 = _8763;
                        _10091 = _8762;
                        _10087 = _8761;
                        continue;
                    }
                    int2 _3768 = clamp(_3661 + int2((_8760 % 3) - 1, (_8760 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5449 = _3362[_8760] & 2147483647u;
                    uint _5481 = uint(max((int((_5449 >> 16u) & 15u) - 6), 0));
                    float2 _3774 = (float2(float((1 - (2 * int((_5449 >> 15u) & 1u))) * int(((_5449 >> uint(7)) & 127u) << _5481)), float((1 - (2 * int((_5449 >> 14u) & 1u))) * int((_5449 & 127u) << _5481))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10041;
                    if (_3362[_8760] == 0u)
                    {
                        _10041 = -1.0f;
                    }
                    else
                    {
                        _10041 = float((_3362[_8760] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3779 = _10041 - 0.100000001490116119384765625f;
                    float2 _10042;
                    if (_5361)
                    {
                        float2 _5558 = clamp((((_8751 + (_3774 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5561 = tan(_5558.x);
                        _10042 = (float2(_5561 / cbFI_DeviceToViewDepth.z, (tan(_5558.y) * sqrt(1.0f + (_5561 * _5561))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10042 = _8751 + (_3774 * cbFI_Timestep);
                    }
                    float _3786 = cbFI_Timestep - 1.0f;
                    float2 _10043;
                    if (_5361)
                    {
                        float2 _5629 = clamp((((_8751 + (_3774 * _3786)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5632 = tan(_5629.x);
                        _10043 = (float2(_5632 / cbFI_DeviceToViewDepth.z, (tan(_5629.y) * sqrt(1.0f + (_5632 * _5632))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10043 = _8751 + (_3774 * _3786);
                    }
                    bool _5665 = all(bool2(_10042.x > 0.0f.xx.x, _10042.y > 0.0f.xx.y));
                    bool _5671;
                    if (_5665)
                    {
                        _5671 = all(bool2(_10042.x < 1.0f.xx.x, _10042.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5671 = _5665;
                    }
                    float _10046;
                    if (_5671)
                    {
                        uint _5678_dummy_parameter;
                        _10046 = max((_3779 - (log(((r_depth_tm1.Load(int3(int2(floor(_10042 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5678_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10046 = 0.0f;
                    }
                    bool _5708 = all(bool2(_10043.x > 0.0f.xx.x, _10043.y > 0.0f.xx.y));
                    bool _5714;
                    if (_5708)
                    {
                        _5714 = all(bool2(_10043.x < 1.0f.xx.x, _10043.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5714 = _5708;
                    }
                    float _10047;
                    if (_5714)
                    {
                        uint _5721_dummy_parameter;
                        _10047 = _10046 + max((_3779 - (log(((r_depth_tp1.Load(int3(int2(floor(_10043 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5721_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10047 = _10046;
                    }
                    float _10088;
                    int2 _10092;
                    float2 _10103;
                    int2 _10114;
                    float2 _10147;
                    float _10192;
                    if (_10047 == 0.0f)
                    {
                        bool _3821 = _3779 > _8761;
                        bool2 _10200 = _3821.xx;
                        _10192 = _10055;
                        _10147 = float2(_10200.x ? _3774.x : _8771.x, _10200.y ? _3774.y : _8771.y);
                        _10114 = int2(_10200.x ? _3768.x : _8765.x, _10200.y ? _3768.y : _8765.y);
                        _10103 = _8763;
                        _10092 = _8762;
                        _10088 = _3821 ? _3779 : _8761;
                    }
                    else
                    {
                        bool _3830 = _10047 < _10055;
                        bool2 _10196 = _3830.xx;
                        _10192 = _3830 ? _10047 : _10055;
                        _10147 = _8771;
                        _10114 = _8765;
                        _10103 = float2(_10196.x ? _3774.x : _8763.x, _10196.y ? _3774.y : _8763.y);
                        _10092 = int2(_10196.x ? _3768.x : _8762.x, _10196.y ? _3768.y : _8762.y);
                        _10088 = _8761;
                    }
                    _10191 = _10192;
                    _10146 = _10147;
                    _10113 = _10114;
                    _10102 = _10103;
                    _10091 = _10092;
                    _10087 = _10088;
                }
                bool _3842 = _8761 < 0.0f;
                bool2 _10206 = _3842.xx;
                int2 _10209 = int2(_10206.x ? _8762.x : _8765.x, _10206.y ? _8762.y : _8765.y);
                _9696 = float3(1.0f, _3733, float(any(bool2(_10209.x != _3661.x, _10209.y != _3661.y))));
                _8805 = _10209;
                _8794 = _3842 ? false : true;
                _8773 = float2(_10206.x ? _8763.x : _8771.x, _10206.y ? _8763.y : _8771.y);
            }
            else
            {
                _9696 = _8566;
                _8805 = _3661;
                _8794 = false;
                _8773 = _5339;
            }
            _9695 = _9696;
            _8804 = _8805;
            _8793 = _8794;
            _8772 = _8773;
        }
        else
        {
            _9695 = 0.0f.xxx;
            _8804 = _3661;
            _8793 = false;
            _8772 = _5339;
        }
        float2 _8774;
        if (_5361)
        {
            float2 _5786 = clamp((((_8751 + (_8772 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5789 = tan(_5786.x);
            _8774 = (float2(_5789 / cbFI_DeviceToViewDepth.z, (tan(_5786.y) * sqrt(1.0f + (_5789 * _5789))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8774 = _8751 + (_8772 * cbFI_Timestep);
        }
        float _3865 = cbFI_Timestep - 1.0f;
        float2 _8776;
        if (_5361)
        {
            float2 _5857 = clamp((((_8751 + (_8772 * _3865)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5860 = tan(_5857.x);
            _8776 = (float2(_5860 / cbFI_DeviceToViewDepth.z, (tan(_5857.y) * sqrt(1.0f + (_5860 * _5860))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8776 = _8751 + (_8772 * _3865);
        }
        float _3870 = -cbFI_Timestep;
        float2 _8777;
        if (_5361)
        {
            float2 _5928 = clamp((((_8751 + (_5333 * _3870)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5931 = tan(_5928.x);
            _8777 = (float2(_5931 / cbFI_DeviceToViewDepth.z, (tan(_5928.y) * sqrt(1.0f + (_5931 * _5931))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8777 = _8751 + (_5333 * _3870);
        }
        float _3875 = 1.0f - cbFI_Timestep;
        float2 _8778;
        if (_5361)
        {
            float2 _5999 = clamp((((_8751 + (_5333 * _3875)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6002 = tan(_5999.x);
            _8778 = (float2(_6002 / cbFI_DeviceToViewDepth.z, (tan(_5999.y) * sqrt(1.0f + (_6002 * _6002))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8778 = _8751 + (_5333 * _3875);
        }
        float4 _6037 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8774, 0.0f);
        float3 _6038 = _6037.xyz;
        float4 _6045 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8776, 0.0f);
        float3 _6046 = _6045.xyz;
        float4 _6053 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8777, 0.0f);
        float3 _6054 = _6053.xyz;
        float4 _6061 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8778, 0.0f);
        float3 _6062 = _6061.xyz;
        float4 _6076 = exp(_5327 - max(max(max(_5327.x, _5327.y), _5327.z), _5327.w).xxxx);
        float4 _6083 = _6076 / (dot(_6076, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3894 = _3687 && (!_8793);
        bool _3903;
        if (_3894)
        {
            _3903 = (_6083.z + _6083.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3903 = _3894;
        }
        bool _3914;
        if (_3903)
        {
            _3914 = length((_8777 - _8774) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3914 = _3903;
        }
        bool _8817;
        if (_3914)
        {
            uint4 _6102 = r_warped_motion_qdata_tp1.Load(int3(_8804, 0));
            uint _6103 = _6102.x;
            bool _8820;
            if (_6103 != 0u)
            {
                float _8806;
                if (_6103 == 0u)
                {
                    _8806 = -1.0f;
                }
                else
                {
                    _8806 = float((_6103 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3924 = _8806 - 0.12000000476837158203125f;
                bool _6122 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                bool _6128;
                if (_6122)
                {
                    _6128 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                }
                else
                {
                    _6128 = _6122;
                }
                bool _3934;
                if (_6128)
                {
                    uint _6135_dummy_parameter;
                    _3934 = (log(((r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6135_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3924;
                }
                else
                {
                    _3934 = _6128;
                }
                bool _3948;
                if (!_3934)
                {
                    bool _6165 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                    bool _6171;
                    if (_6165)
                    {
                        _6171 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6171 = _6165;
                    }
                    bool _3946;
                    if (_6171)
                    {
                        uint _6178_dummy_parameter;
                        _3946 = (log(((r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6178_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _3924;
                    }
                    else
                    {
                        _3946 = _6171;
                    }
                    _3948 = _3946;
                }
                else
                {
                    _3948 = _3934;
                }
                _8820 = _3948;
            }
            else
            {
                _8820 = false;
            }
            _8817 = _8820;
        }
        else
        {
            _8817 = false;
        }
        bool _3953 = _8793 || _8817;
        bool _3958;
        if (_3953)
        {
            bool _6208 = all(bool2(_8774.x > 0.0f.xx.x, _8774.y > 0.0f.xx.y));
            bool _6214;
            if (_6208)
            {
                _6214 = all(bool2(_8774.x < 1.0f.xx.x, _8774.y < 1.0f.xx.y));
            }
            else
            {
                _6214 = _6208;
            }
            _3958 = _6214;
        }
        else
        {
            _3958 = _3953;
        }
        bool _3963;
        if (_3958)
        {
            bool _6219 = all(bool2(_8776.x > 0.0f.xx.x, _8776.y > 0.0f.xx.y));
            bool _6225;
            if (_6219)
            {
                _6225 = all(bool2(_8776.x < 1.0f.xx.x, _8776.y < 1.0f.xx.y));
            }
            else
            {
                _6225 = _6219;
            }
            _3963 = _6225;
        }
        else
        {
            _3963 = _3958;
        }
        float4 _8911;
        if (_3963)
        {
            float _3966 = _6083.x;
            float _3968 = _6083.y;
            float _3969 = _3966 + _3968;
            float _3974 = _6083.z + _6083.w;
            float _8835;
            if (_3969 > 0.001000000047497451305389404296875f)
            {
                _8835 = _3966 / _3969;
            }
            else
            {
                _8835 = _3875;
            }
            _8911 = float4(_3966 + (_3974 * _8835), _3968 + (_3974 * (1.0f - _8835)), 0.0f, 0.0f);
        }
        else
        {
            _8911 = _6083;
        }
        bool _6253 = (cbFI_pad0 & 1024u) != 0u;
        bool _6229 = !_6253;
        bool _6230 = !_6229;
        bool _6247;
        if (_6230)
        {
            _6247 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_8804.y * cbFI_MvDepthLaneSize.x) + _8804.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6247 = _6229;
        }
        bool _6279;
        if (_6230)
        {
            _6279 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3666.y * cbFI_FlowLaneSize.x) + _3666.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6279 = _6229;
        }
        float _4009 = float(_6279);
        bool _8923;
        float4 _8953;
        float3 _9555;
        if (_6253)
        {
            bool _4019;
            if (_6247)
            {
                _4019 = all(bool2(_8774.x > 0.0f.xx.x, _8774.y > 0.0f.xx.y));
            }
            else
            {
                _4019 = _6247;
            }
            bool _4025;
            if (_4019)
            {
                _4025 = all(bool2(_8774.x < 1.0f.xx.x, _8774.y < 1.0f.xx.y));
            }
            else
            {
                _4025 = _4019;
            }
            bool _4032;
            if (_6247)
            {
                _4032 = all(bool2(_8776.x > 0.0f.xx.x, _8776.y > 0.0f.xx.y));
            }
            else
            {
                _4032 = _6247;
            }
            bool _4038;
            if (_4032)
            {
                _4038 = all(bool2(_8776.x < 1.0f.xx.x, _8776.y < 1.0f.xx.y));
            }
            else
            {
                _4038 = _4032;
            }
            bool _4045;
            if (_6279)
            {
                _4045 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
            }
            else
            {
                _4045 = _6279;
            }
            bool _4051;
            if (_4045)
            {
                _4051 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
            }
            else
            {
                _4051 = _4045;
            }
            bool _4058;
            if (_6279)
            {
                _4058 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
            }
            else
            {
                _4058 = _6279;
            }
            bool _4064;
            if (_4058)
            {
                _4064 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
            }
            else
            {
                _4064 = _4058;
            }
            bool _4066 = !_6247;
            if (_4066)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6321;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6321);
                }
            }
            bool _4071 = !_6279;
            if (_4071)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6331;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6331);
                }
            }
            if (_6247 && _4071)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6341;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6341);
                }
            }
            if (_4066 && _6279)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6351;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6351);
                }
            }
            float _4090 = float(_4025);
            float _4092 = float(_4038);
            bool _4095 = _4051 && _4064;
            float _8869;
            if (_4095)
            {
                _8869 = 1.0f;
            }
            else
            {
                _8869 = (_4051 || _4064) ? 0.5f : 0.0f;
            }
            bool _8874;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4025)) && (!_4038))
            {
                bool _4125;
                if (_4095)
                {
                    float _8872;
                    do
                    {
                        bool _6435 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                        bool _6441;
                        if (_6435)
                        {
                            _6441 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6441 = _6435;
                        }
                        bool _6372 = !_6441;
                        bool _6379;
                        if (!_6372)
                        {
                            bool _6446 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                            bool _6452;
                            if (_6446)
                            {
                                _6452 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6452 = _6446;
                            }
                            _6379 = !_6452;
                        }
                        else
                        {
                            _6379 = _6372;
                        }
                        if (_6379)
                        {
                            _8872 = 0.0f;
                            break;
                        }
                        uint _6459_dummy_parameter;
                        uint _6475_dummy_parameter;
                        float4 _6400 = mul(float4((float2(_8777.x, 1.0f - _8777.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6459_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6402 = _6400.w;
                        if (abs(_6402) < 9.9999999747524270787835121154785e-07f)
                        {
                            _8872 = 0.0f;
                            break;
                        }
                        float _6413 = abs(cbFI_DeviceToViewDepth.y / ((_6400.z / _6402) - cbFI_DeviceToViewDepth.x));
                        float _6416 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6475_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _8872 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6413 - _6416) / max(max(_6413, _6416), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4125 = _8872 >= 0.5f;
                }
                else
                {
                    _4125 = _4095;
                }
                bool _8875;
                if (_4125)
                {
                    uint _6525_dummy_parameter;
                    float2 _8873;
                    do
                    {
                        float _6551 = 1.0f - _8777.y;
                        float4 _6562 = mul(float4((float2(_8777.x, _6551) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6525_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6564 = _6562.w;
                        if (!(_6564 > 9.9999999747524270787835121154785e-07f))
                        {
                            _8873 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6577 = ((_6562.xy / _6564.xx) + 1.0f.xx) * 0.5f;
                        _8873 = float2(_6577.x - _8777.x, _6551 - _6577.y);
                        break;
                    } while(false);
                    float2 _4139 = float2(cbFI_DisplaySize);
                    _8875 = length(((_8777 + _8873) - _8778) * _4139) <= ((0.100000001490116119384765625f * length(_8873 * _4139)) + 8.0f);
                }
                else
                {
                    _8875 = _4125;
                }
                _8874 = _8875;
            }
            else
            {
                _8874 = true;
            }
            bool _4153 = !_8874;
            bool _10210 = _4153 ? false : _4064;
            bool _10211 = _4153 ? false : _4051;
            bool _8924;
            float4 _8954;
            if (!(((_4025 && _4038) && _10211) && _10210))
            {
                float4 _4175 = _8911 * float4(_4090, _4092, float(_10211), float(_10210));
                float _4177 = dot(_4175, 1.0f.xxxx);
                bool _4180 = !(_4177 > 0.0f);
                float4 _8955;
                if (!_4180)
                {
                    _8955 = _4175 / _4177.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6599;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6599);
                    }
                    _8955 = 0.0f.xxxx;
                }
                _8954 = _8955;
                _8924 = _4180;
            }
            else
            {
                _8954 = _8911;
                _8924 = false;
            }
            _9555 = float3(_4090, _4092, _8869);
            _8953 = _8954;
            _8923 = _8924;
        }
        else
        {
            _9555 = float3(float(_6247), _4009, 0.0f);
            _8953 = _8911;
            _8923 = false;
        }
        float4 _9425;
        bool _9445;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_8923))
        {
            bool _4203 = _8953.x > 0.00999999977648258209228515625f;
            bool _4206 = _8953.y > 0.00999999977648258209228515625f;
            bool _4215 = (_8953.z + _8953.w) > 0.0199999995529651641845703125f;
            bool _4221;
            if (_4215)
            {
                bool _6605 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                bool _6611;
                if (_6605)
                {
                    _6611 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                }
                else
                {
                    _6611 = _6605;
                }
                _4221 = _6611;
            }
            else
            {
                _4221 = _4215;
            }
            bool _4226;
            if (_4221)
            {
                bool _6616 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                bool _6622;
                if (_6616)
                {
                    _6622 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                }
                else
                {
                    _6622 = _6616;
                }
                _4226 = _6622;
            }
            else
            {
                _4226 = _4221;
            }
            bool _4233;
            if (_4226)
            {
                float _8957;
                do
                {
                    bool _6705 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                    bool _6711;
                    if (_6705)
                    {
                        _6711 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6711 = _6705;
                    }
                    bool _6642 = !_6711;
                    bool _6649;
                    if (!_6642)
                    {
                        bool _6716 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                        bool _6722;
                        if (_6716)
                        {
                            _6722 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6722 = _6716;
                        }
                        _6649 = !_6722;
                    }
                    else
                    {
                        _6649 = _6642;
                    }
                    if (_6649)
                    {
                        _8957 = 0.0f;
                        break;
                    }
                    uint _6729_dummy_parameter;
                    uint _6745_dummy_parameter;
                    float4 _6670 = mul(float4((float2(_8777.x, 1.0f - _8777.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6729_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6672 = _6670.w;
                    if (abs(_6672) < 9.9999999747524270787835121154785e-07f)
                    {
                        _8957 = 0.0f;
                        break;
                    }
                    float _6683 = abs(cbFI_DeviceToViewDepth.y / ((_6670.z / _6672) - cbFI_DeviceToViewDepth.x));
                    float _6686 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6745_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _8957 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6683 - _6686) / max(max(_6683, _6686), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4233 = _8957 < 0.5f;
            }
            else
            {
                _4233 = _4226;
            }
            float4 _8972;
            if (_4233)
            {
                uint _6795_dummy_parameter;
                uint _6826_dummy_parameter;
                float4 _8973;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6795_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6826_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _8973 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _8973 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _8972 = _8973;
            }
            else
            {
                _8972 = 1.0f.xxxx;
            }
            bool _4257;
            if (_6247)
            {
                bool _6855 = all(bool2(_8774.x > 0.0f.xx.x, _8774.y > 0.0f.xx.y));
                bool _6861;
                if (_6855)
                {
                    _6861 = all(bool2(_8774.x < 1.0f.xx.x, _8774.y < 1.0f.xx.y));
                }
                else
                {
                    _6861 = _6855;
                }
                _4257 = _6861;
            }
            else
            {
                _4257 = _6247;
            }
            bool _4263;
            if (_6247)
            {
                bool _6866 = all(bool2(_8776.x > 0.0f.xx.x, _8776.y > 0.0f.xx.y));
                bool _6872;
                if (_6866)
                {
                    _6872 = all(bool2(_8776.x < 1.0f.xx.x, _8776.y < 1.0f.xx.y));
                }
                else
                {
                    _6872 = _6866;
                }
                _4263 = _6872;
            }
            else
            {
                _4263 = _6247;
            }
            bool _4269;
            if (_6279)
            {
                bool _6877 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                bool _6883;
                if (_6877)
                {
                    _6883 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                }
                else
                {
                    _6883 = _6877;
                }
                _4269 = _6883;
            }
            else
            {
                _4269 = _6279;
            }
            bool _4275;
            if (_6279)
            {
                bool _6888 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                bool _6894;
                if (_6888)
                {
                    _6894 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                }
                else
                {
                    _6894 = _6888;
                }
                _4275 = _6894;
            }
            else
            {
                _4275 = _6279;
            }
            bool _4278 = _4269 != _4275;
            bool _4284;
            if (_4278)
            {
                _4284 = _4257 || _4263;
            }
            else
            {
                _4284 = _4278;
            }
            float4 _9075;
            if (_4284)
            {
                float4 _8651 = _8972;
                _8651.z = 0.0f;
                _8651.w = 0.0f;
                _9075 = _8651;
            }
            else
            {
                _9075 = _8972;
            }
            bool _4291 = _4257 && _4203;
            bool _4294 = _4263 && _4206;
            float4 _9150;
            if (_4291 || _4294)
            {
                float _9049;
                do
                {
                    uint4 _7033 = r_warped_motion_qdata_tp1.Load(int3(_8804, 0));
                    uint _7034 = _7033.x;
                    if (_7034 != 0u)
                    {
                        float _9048;
                        if (_7034 == 0u)
                        {
                            _9048 = -1.0f;
                        }
                        else
                        {
                            _9048 = float((_7034 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9049 = _9048;
                        break;
                    }
                    int _9031;
                    uint _9032;
                    _9032 = _7034;
                    _9031 = -1;
                    uint _9047;
                    for (; _9031 <= 1; _9032 = _9047, _9031++)
                    {
                        _9047 = _9032;
                        for (int _9045 = -1; _9045 <= 1; )
                        {
                            _9047 = max(_9047, r_warped_motion_qdata_tp1.Load(int3(clamp(_8804 + int2(_9045, _9031), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9045++;
                            continue;
                        }
                    }
                    if (_9032 != 0u)
                    {
                        float _9044;
                        if (_9032 == 0u)
                        {
                            _9044 = -1.0f;
                        }
                        else
                        {
                            _9044 = float((_9032 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9049 = _9044;
                        break;
                    }
                    uint _9034;
                    _9034 = 4294967295u;
                    uint _10183;
                    for (int _9033 = 0; _9033 < 8; _9034 = _10183, _9033++)
                    {
                        int _9037 = 0;
                        for (;;)
                        {
                            if (_9037 < 5)
                            {
                                int2 _6984 = _8804 + (_1085[_9033] * _1094[_9037].xx);
                                bool _6987 = any(bool2(_6984.x < int2(0, 0).x, _6984.y < int2(0, 0).y));
                                bool _6995;
                                if (!_6987)
                                {
                                    _6995 = any(bool2(_6984.x >= cbFI_MvDepthLaneSize.x, _6984.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _6995 = _6987;
                                }
                                if (_6995)
                                {
                                    _10183 = _9034;
                                    break;
                                }
                                uint4 _7073 = r_warped_motion_qdata_tp1.Load(int3(_6984, 0));
                                uint _7074 = _7073.x;
                                if (_7074 != 0u)
                                {
                                    _10183 = min(_9034, _7074);
                                    break;
                                }
                                _9037++;
                                continue;
                            }
                            else
                            {
                                _10183 = _9034;
                                break;
                            }
                        }
                    }
                    float _9036;
                    if (_9034 == 4294967295u)
                    {
                        _9036 = -1.0f;
                    }
                    else
                    {
                        float _9035;
                        if (_9034 == 0u)
                        {
                            _9035 = -1.0f;
                        }
                        else
                        {
                            _9035 = float((_9034 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9036 = _9035;
                    }
                    _9049 = _9036;
                    break;
                } while(false);
                float _4305 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4307 = _9049 >= 0.0f;
                float _9056;
                if (_4307)
                {
                    _9056 = _9049 - _4305;
                }
                else
                {
                    float _9052;
                    if (_4291)
                    {
                        float _9051;
                        _9051 = 2.0f;
                        float _7145;
                        for (int _9050 = 0; _9050 < 24; _9051 = _7145, _9050++)
                        {
                            float _7109 = float(_9050 & 7) * 0.785398185253143310546875f;
                            int _7111 = _9050 >> 3;
                            int _9053;
                            if (_7111 == 0)
                            {
                                _9053 = 16;
                            }
                            else
                            {
                                _9053 = (_7111 == 1) ? 48 : 96;
                            }
                            uint _7161_dummy_parameter;
                            _7145 = min(_9051, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_8774 + ((cbFI_MvDepthLaneSizeRcp * float(_9053)) * float2(cos(_7109), sin(_7109))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7161_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9052 = _9051;
                    }
                    else
                    {
                        _9052 = 0.0f;
                    }
                    _9056 = _9052;
                }
                float _9063;
                if (_4307)
                {
                    _9063 = _9049 - _4305;
                }
                else
                {
                    float _9059;
                    if (_4294)
                    {
                        float _9058;
                        _9058 = 2.0f;
                        float _7259;
                        for (int _9057 = 0; _9057 < 24; _9058 = _7259, _9057++)
                        {
                            float _7223 = float(_9057 & 7) * 0.785398185253143310546875f;
                            int _7225 = _9057 >> 3;
                            int _9060;
                            if (_7225 == 0)
                            {
                                _9060 = 16;
                            }
                            else
                            {
                                _9060 = (_7225 == 1) ? 48 : 96;
                            }
                            uint _7291_dummy_parameter;
                            _7259 = min(_9058, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_8776 + ((cbFI_MvDepthLaneSizeRcp * float(_9060)) * float2(cos(_7223), sin(_7223))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7291_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9059 = _9058;
                    }
                    else
                    {
                        _9059 = 0.0f;
                    }
                    _9063 = _9059;
                }
                float _9064;
                if (_4291)
                {
                    uint _7323_dummy_parameter;
                    _9064 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_8774 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7323_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9064 = 0.0f;
                }
                float _9065;
                if (_4294)
                {
                    uint _7343_dummy_parameter;
                    _9065 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_8776 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7343_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9065 = 0.0f;
                }
                bool _4362;
                if (_4291)
                {
                    _4362 = _9064 > ((exp((_9056 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4362 = _4291;
                }
                float4 _9090;
                if (_4362)
                {
                    float4 _8655 = _9075;
                    _8655.x = 0.0f;
                    _9090 = _8655;
                }
                else
                {
                    _9090 = _9075;
                }
                bool _4374;
                if (_4294)
                {
                    _4374 = _9065 > ((exp((_9063 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4374 = _4294;
                }
                float4 _9092;
                if (_4374)
                {
                    float4 _8657 = _9090;
                    _8657.y = 0.0f;
                    _9092 = _8657;
                }
                else
                {
                    _9092 = _9090;
                }
                float4 _9151;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4307)
                {
                    bool _4394;
                    if (_4291)
                    {
                        _4394 = _9064 < ((exp((_9056 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4394 = _4291;
                    }
                    float4 _9094;
                    if (_4394)
                    {
                        float4 _8659 = _9092;
                        _8659.x = 0.0f;
                        _9094 = _8659;
                    }
                    else
                    {
                        _9094 = _9092;
                    }
                    bool _4406;
                    if (_4294)
                    {
                        _4406 = _9065 < ((exp((_9063 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4406 = _4294;
                    }
                    float4 _9152;
                    if (_4406)
                    {
                        float4 _8661 = _9094;
                        _8661.y = 0.0f;
                        _9152 = _8661;
                    }
                    else
                    {
                        _9152 = _9094;
                    }
                    _9151 = _9152;
                }
                else
                {
                    _9151 = _9092;
                }
                _9150 = _9151;
            }
            else
            {
                _9150 = _9075;
            }
            bool _4417 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4215;
            bool _4423;
            if (_4417)
            {
                _4423 = _4269 || _4275;
            }
            else
            {
                _4423 = _4417;
            }
            float4 _9172;
            if (_4423)
            {
                float _9145;
                do
                {
                    uint4 _7523 = r_warped_motion_qdata_tp1.Load(int3(_8804, 0));
                    uint _7524 = _7523.x;
                    if (_7524 != 0u)
                    {
                        float _9144;
                        if (_7524 == 0u)
                        {
                            _9144 = -1.0f;
                        }
                        else
                        {
                            _9144 = float((_7524 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9145 = _9144;
                        break;
                    }
                    int _9127;
                    uint _9128;
                    _9128 = _7524;
                    _9127 = -1;
                    uint _9143;
                    for (; _9127 <= 1; _9128 = _9143, _9127++)
                    {
                        _9143 = _9128;
                        for (int _9141 = -1; _9141 <= 1; )
                        {
                            _9143 = max(_9143, r_warped_motion_qdata_tp1.Load(int3(clamp(_8804 + int2(_9141, _9127), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9141++;
                            continue;
                        }
                    }
                    if (_9128 != 0u)
                    {
                        float _9140;
                        if (_9128 == 0u)
                        {
                            _9140 = -1.0f;
                        }
                        else
                        {
                            _9140 = float((_9128 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9145 = _9140;
                        break;
                    }
                    uint _9130;
                    _9130 = 4294967295u;
                    uint _10184;
                    for (int _9129 = 0; _9129 < 8; _9130 = _10184, _9129++)
                    {
                        int _9133 = 0;
                        for (;;)
                        {
                            if (_9133 < 5)
                            {
                                int2 _7474 = _8804 + (_1085[_9129] * _1094[_9133].xx);
                                bool _7477 = any(bool2(_7474.x < int2(0, 0).x, _7474.y < int2(0, 0).y));
                                bool _7485;
                                if (!_7477)
                                {
                                    _7485 = any(bool2(_7474.x >= cbFI_MvDepthLaneSize.x, _7474.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7485 = _7477;
                                }
                                if (_7485)
                                {
                                    _10184 = _9130;
                                    break;
                                }
                                uint4 _7563 = r_warped_motion_qdata_tp1.Load(int3(_7474, 0));
                                uint _7564 = _7563.x;
                                if (_7564 != 0u)
                                {
                                    _10184 = min(_9130, _7564);
                                    break;
                                }
                                _9133++;
                                continue;
                            }
                            else
                            {
                                _10184 = _9130;
                                break;
                            }
                        }
                    }
                    float _9132;
                    if (_9130 == 4294967295u)
                    {
                        _9132 = -1.0f;
                    }
                    else
                    {
                        float _9131;
                        if (_9130 == 0u)
                        {
                            _9131 = -1.0f;
                        }
                        else
                        {
                            _9131 = float((_9130 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9132 = _9131;
                    }
                    _9145 = _9132;
                    break;
                } while(false);
                float4 _9173;
                if (_9145 >= 0.0f)
                {
                    float _7585 = (exp((_9145 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4442;
                    if (_4269)
                    {
                        uint _7592_dummy_parameter;
                        _4442 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7592_dummy_parameter))))), 0)).x) > _7585;
                    }
                    else
                    {
                        _4442 = _4269;
                    }
                    float4 _9163;
                    if (_4442)
                    {
                        float4 _8663 = _9150;
                        _8663.z = 0.0f;
                        _9163 = _8663;
                    }
                    else
                    {
                        _9163 = _9150;
                    }
                    bool _4454;
                    if (_4275)
                    {
                        uint _7612_dummy_parameter;
                        _4454 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7612_dummy_parameter))))), 0)).x) > _7585;
                    }
                    else
                    {
                        _4454 = _4275;
                    }
                    float4 _9174;
                    if (_4454)
                    {
                        float4 _8665 = _9163;
                        _8665.w = 0.0f;
                        _9174 = _8665;
                    }
                    else
                    {
                        _9174 = _9163;
                    }
                    _9173 = _9174;
                }
                else
                {
                    _9173 = _9150;
                }
                _9172 = _9173;
            }
            else
            {
                _9172 = _9150;
            }
            bool _4462 = _4257 != _4263;
            bool _4469;
            if (_4462)
            {
                _4469 = _4257 ? _4203 : _4206;
            }
            else
            {
                _4469 = _4462;
            }
            float4 _9252;
            if (_4469)
            {
                bool2 _4474 = _4257.xx;
                float2 _4475 = float2(_4474.x ? _8774.x : _8776.x, _4474.y ? _8774.y : _8776.y);
                float _9165;
                if (_4257)
                {
                    uint _7632_dummy_parameter;
                    _9165 = r_depth_tm1.Load(int3(int2(floor(_4475 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7632_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7648_dummy_parameter;
                    _9165 = r_depth_tp1.Load(int3(int2(floor(_4475 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7648_dummy_parameter))))), 0)).x;
                }
                float4x4 _9166;
                if (_4257)
                {
                    _9166 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9166 = cbFI_MotionTP1ToTM1;
                }
                float2 _9167;
                do
                {
                    float _7675 = _4475.x;
                    float _7678 = 1.0f - _4475.y;
                    float4 _7689 = mul(float4((float2(_7675, _7678) * 2.0f) - 1.0f.xx, _9165, 1.0f), _9166);
                    float _7691 = _7689.w;
                    if (!(_7691 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9167 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7704 = ((_7689.xy / _7691.xx) + 1.0f.xx) * 0.5f;
                    _9167 = float2(_7704.x - _7675, _7678 - _7704.y);
                    break;
                } while(false);
                float2 _4505 = float2(cbFI_DisplaySize);
                float4 _9253;
                if (!(length(((_4475 + _9167) - float2(_4474.x ? _8776.x : _8774.x, _4474.y ? _8776.y : _8774.y)) * _4505) <= ((0.100000001490116119384765625f * length(_9167 * _4505)) + 8.0f)))
                {
                    float4 _9254;
                    if (_4257)
                    {
                        float4 _8675 = _9172;
                        _8675.x = 0.0f;
                        _9254 = _8675;
                    }
                    else
                    {
                        float4 _8677 = _9172;
                        _8677.y = 0.0f;
                        _9254 = _8677;
                    }
                    _9253 = _9254;
                }
                else
                {
                    _9253 = _9172;
                }
                _9252 = _9253;
            }
            else
            {
                _9252 = _9172;
            }
            float4 _4530 = _8953 * _9252;
            float _4532 = dot(_4530, 1.0f.xxxx);
            float4 _9426;
            bool _9446;
            if (_4532 > 0.0f)
            {
                _9446 = _8923;
                _9426 = _4530 / _4532.xxxx;
            }
            else
            {
                bool _4543 = any(bool4(_9252.x < 1.0f.xxxx.x, _9252.y < 1.0f.xxxx.y, _9252.z < 1.0f.xxxx.z, _9252.w < 1.0f.xxxx.w));
                if (_4543)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7726;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7726);
                    }
                }
                bool4 _10213 = _4543.xxxx;
                _9446 = _4543 ? true : _8923;
                _9426 = float4(_10213.x ? 0.0f.xxxx.x : _8953.x, _10213.y ? 0.0f.xxxx.y : _8953.y, _10213.z ? 0.0f.xxxx.z : _8953.z, _10213.w ? 0.0f.xxxx.w : _8953.w);
            }
            _9445 = _9446;
            _9425 = _9426;
        }
        else
        {
            _9445 = _8923;
            _9425 = _8953;
        }
        uint _4552 = (cbFI_pad0 >> 24u) & 31u;
        uint _4556 = (cbFI_pad0 >> 16u) & 255u;
        bool _4558 = _4552 != 0u;
        bool _4560 = _4556 == 12u;
        bool _4563 = _4556 == 13u;
        float4 _9442;
        if ((_4558 || _4560) || _4563)
        {
            float _9255;
            do
            {
                bool _7810 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                bool _7816;
                if (_7810)
                {
                    _7816 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                }
                else
                {
                    _7816 = _7810;
                }
                bool _7747 = !_7816;
                bool _7754;
                if (!_7747)
                {
                    bool _7821 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                    bool _7827;
                    if (_7821)
                    {
                        _7827 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7827 = _7821;
                    }
                    _7754 = !_7827;
                }
                else
                {
                    _7754 = _7747;
                }
                if (_7754)
                {
                    _9255 = 0.0f;
                    break;
                }
                uint _7834_dummy_parameter;
                uint _7850_dummy_parameter;
                float4 _7775 = mul(float4((float2(_8777.x, 1.0f - _8777.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7834_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7777 = _7775.w;
                if (abs(_7777) < 9.9999999747524270787835121154785e-07f)
                {
                    _9255 = 0.0f;
                    break;
                }
                float _7788 = abs(cbFI_DeviceToViewDepth.y / ((_7775.z / _7777) - cbFI_DeviceToViewDepth.x));
                float _7791 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7850_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9255 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7788 - _7791) / max(max(_7788, _7791), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _7898 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
            bool _7904;
            if (_7898)
            {
                _7904 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
            }
            else
            {
                _7904 = _7898;
            }
            float _9256;
            if (_7904)
            {
                uint _7911_dummy_parameter;
                _9256 = length((_5333 + (r_motion_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7911_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9256 = 1000000.0f;
            }
            float _9267;
            if ((_4552 & 1u) != 0u)
            {
                _9267 = _9255;
            }
            else
            {
                _9267 = 1.0f;
            }
            float _9268;
            if ((_4552 & 2u) != 0u)
            {
                _9268 = _9267 * (1.0f - smoothstep(2.0f, 8.0f, _9256));
            }
            else
            {
                _9268 = _9267;
            }
            float _9269;
            if ((_4552 & 4u) != 0u)
            {
                _9269 = _9268 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6054 - _6062) - length(_6038 - _6046))));
            }
            else
            {
                _9269 = _9268;
            }
            float _9436;
            if ((_4552 & 8u) != 0u)
            {
                _9436 = lerp(1.0f, _9269, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6038 - _6046)));
            }
            else
            {
                _9436 = _9269;
            }
            bool _4638 = (_4552 & 16u) != 0u;
            bool _4647;
            if (_4638)
            {
                _4647 = length(_8772 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4647 = _4638;
            }
            float _10215 = _4647 ? 1.0f : _9436;
            bool _4653 = _4558 && _6247;
            bool _4658;
            if (_4653)
            {
                bool _7936 = all(bool2(_8774.x > 0.0f.xx.x, _8774.y > 0.0f.xx.y));
                bool _7942;
                if (_7936)
                {
                    _7942 = all(bool2(_8774.x < 1.0f.xx.x, _8774.y < 1.0f.xx.y));
                }
                else
                {
                    _7942 = _7936;
                }
                _4658 = _7942;
            }
            else
            {
                _4658 = _4653;
            }
            bool _4663;
            if (_4658)
            {
                bool _7947 = all(bool2(_8776.x > 0.0f.xx.x, _8776.y > 0.0f.xx.y));
                bool _7953;
                if (_7947)
                {
                    _7953 = all(bool2(_8776.x < 1.0f.xx.x, _8776.y < 1.0f.xx.y));
                }
                else
                {
                    _7953 = _7947;
                }
                _4663 = _7953;
            }
            else
            {
                _4663 = _4658;
            }
            float4 _9443;
            if (_4663)
            {
                float _4669 = _9425.x + _9425.y;
                float _4678 = (_9425.z + _9425.w) * (1.0f - _10215);
                float _9439;
                if (_4669 > 9.9999997473787516355514526367188e-06f)
                {
                    _9439 = _9425.x / _4669;
                }
                else
                {
                    _9439 = _3875;
                }
                _9443 = float4(_9425.x + (_4678 * _9439), _9425.y + (_4678 * (1.0f - _9439)), _9425.zw * _10215);
            }
            else
            {
                _9443 = _9425;
            }
            _9442 = _9443;
        }
        else
        {
            _9442 = _9425;
        }
        float3 _9988;
        if (_9445)
        {
            float3 _7959 = r_current_interpolation_source.Load(int3(_3300, 0)).xyz;
            float3 _9989;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6247)
            {
                uint _7966_dummy_parameter;
                float _9545;
                _9545 = r_depth_tm1.Load(int3(int2(floor(_8774 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7966_dummy_parameter))))), 0)).x;
                float _4790;
                for (int _9544 = 0; _9544 < 24; _9545 = _4790, _9544++)
                {
                    float _4762 = float(_9544 & 7) * 0.785398185253143310546875f;
                    int _4764 = _9544 >> 3;
                    int _10038;
                    if (_4764 == 0)
                    {
                        _10038 = 16;
                    }
                    else
                    {
                        _10038 = (_4764 == 1) ? 48 : 96;
                    }
                    uint _7986_dummy_parameter;
                    _4790 = max(_9545, r_depth_tm1.Load(int3(int2(floor(clamp(_8774 + ((cbFI_MvDepthLaneSizeRcp * float(_10038)) * float2(cos(_4762), sin(_4762))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7986_dummy_parameter))))), 0)).x);
                }
                float2 _9546;
                do
                {
                    float _8008 = 1.0f - _8774.y;
                    float4 _8019 = mul(float4((float2(_8774.x, _8008) * 2.0f) - 1.0f.xx, _9545, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8021 = _8019.w;
                    if (!(_8021 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9546 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8034 = ((_8019.xy / _8021.xx) + 1.0f.xx) * 0.5f;
                    _9546 = float2(_8034.x - _8774.x, _8008 - _8034.y);
                    break;
                } while(false);
                float2 _4801 = _8774 + _9546;
                bool _8052 = all(bool2(_4801.x > 0.0f.xx.x, _4801.y > 0.0f.xx.y));
                bool _8058;
                if (_8052)
                {
                    _8058 = all(bool2(_4801.x < 1.0f.xx.x, _4801.y < 1.0f.xx.y));
                }
                else
                {
                    _8058 = _8052;
                }
                float3 _9990;
                if (_8058)
                {
                    float _4807 = abs(cbFI_DeviceToViewDepth.y / (_9545 - cbFI_DeviceToViewDepth.x));
                    uint _8078_dummy_parameter;
                    int2 _8078 = int2(spvTextureSize(r_depth_m2, uint(0), _8078_dummy_parameter));
                    float _4811 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4801 * float2(_8078))), int2(0, 0), _8078 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _9995;
                    if (abs(_4811 - _4807) <= (0.20000000298023223876953125f * max(_4811, _4807)))
                    {
                        uint _8112_dummy_parameter;
                        int2 _8112 = int2(spvTextureSize(r_colour_m2, uint(0), _8112_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8135;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8135);
                        }
                        _9995 = r_colour_m2.Load(int3(clamp(int2(floor(_4801 * float2(_8112))), int2(0, 0), _8112 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8145;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8145);
                        }
                        _9995 = _7959;
                    }
                    _9990 = _9995;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8155;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8155);
                    }
                    _9990 = _7959;
                }
                _9989 = _9990;
            }
            else
            {
                _9989 = _7959;
            }
            _9988 = _9989;
        }
        else
        {
            _9988 = (((_6038 * _9442.x) + (_6046 * _9442.y)) + (_6054 * _9442.z)) + (_6062 * _9442.w);
        }
        uint _4839 = cbFI_pad0 & 255u;
        bool _9883;
        float3 _9987;
        if (_4839 != 0u)
        {
            float3 _4844 = r_present_backbuffer.Load(int3(_3300, 0)).xyz;
            float3 _4848 = r_current_interpolation_source.Load(int3(_3300, 0)).xyz;
            float3 _4852 = abs(_4844 - _4848);
            float3 _9549;
            if (_4839 == 2u)
            {
                _9549 = (abs(_4848) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9549 = 0.000244140625f.xxx;
            }
            bool _4868 = any(bool3(_4852.x > _9549.x, _4852.y > _9549.y, _4852.z > _9549.z));
            bool3 _10216 = _4868.xxx;
            _9987 = float3(_10216.x ? _4844.x : _9988.x, _10216.y ? _4844.y : _9988.y, _10216.z ? _4844.z : _9988.z);
            _9883 = _4868;
        }
        else
        {
            _9987 = _9988;
            _9883 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8170;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8170);
        }
        float3 _9971;
        if (_4556 == 1u)
        {
            _9971 = lerp(_6038, _6046, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _9972;
            if (_4556 == 2u)
            {
                _9972 = lerp(_6054, _6062, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _9973;
                if (_4556 == 3u)
                {
                    _9973 = float(_9883).xxx;
                }
                else
                {
                    float3 _9974;
                    if (_4556 == 4u)
                    {
                        _9974 = float3(((_8772 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _9975;
                        if (_4556 == 5u)
                        {
                            _9975 = float3(((_5333 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _9976;
                            if (_4556 == 6u)
                            {
                                _9976 = float3(_9442.xy, _9442.z + _9442.w);
                            }
                            else
                            {
                                float3 _9977;
                                if (_4556 == 7u)
                                {
                                    _9977 = r_current_interpolation_source.Load(int3(_3300, 0)).xyz;
                                }
                                else
                                {
                                    float3 _9978;
                                    if (_4556 == 8u)
                                    {
                                        _9978 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3650, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _9979;
                                        if (_4560)
                                        {
                                            uint _8192_dummy_parameter;
                                            uint _8224_dummy_parameter;
                                            _9979 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3650 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8192_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3650 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8224_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _9980;
                                            if (_4563)
                                            {
                                                _9980 = _6054;
                                            }
                                            else
                                            {
                                                float3 _9981;
                                                if (_4556 == 20u)
                                                {
                                                    _9981 = _6038;
                                                }
                                                else
                                                {
                                                    float3 _9982;
                                                    if (_4556 == 21u)
                                                    {
                                                        _9982 = _6046;
                                                    }
                                                    else
                                                    {
                                                        float3 _9983;
                                                        if (_4556 == 22u)
                                                        {
                                                            _9983 = _6062;
                                                        }
                                                        else
                                                        {
                                                            float3 _9984;
                                                            if (_4556 == 18u)
                                                            {
                                                                _9984 = _9695;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10218 = (_4556 == 19u).xxx;
                                                                _9984 = float3(_10218.x ? _9555.x : _9987.x, _10218.y ? _9555.y : _9987.y, _10218.z ? _9555.z : _9987.z);
                                                            }
                                                            _9983 = _9984;
                                                        }
                                                        _9982 = _9983;
                                                    }
                                                    _9981 = _9982;
                                                }
                                                _9980 = _9981;
                                            }
                                            _9979 = _9980;
                                        }
                                        _9978 = _9979;
                                    }
                                    _9977 = _9978;
                                }
                                _9976 = _9977;
                            }
                            _9975 = _9976;
                        }
                        _9974 = _9975;
                    }
                    _9973 = _9974;
                }
                _9972 = _9973;
            }
            _9971 = _9972;
        }
        float3 _9970;
        if ((_4556 >= 9u) && (_4556 <= 11u))
        {
            uint _5026 = 64u + uint((_8804.y * cbFI_MvDepthLaneSize.x) + _8804.x);
            uint _5030 = rw_nfru_diagnostics.Load<uint>(_5026 * 4 + 0) & 15u;
            float3 _10000;
            if (_4556 == 10u)
            {
                float3 _9969;
                if ((rw_nfru_diagnostics.Load<uint>(_5026 * 4 + 0) & 32u) != 0u)
                {
                    _9969 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _9968;
                    if ((rw_nfru_diagnostics.Load<uint>(_5026 * 4 + 0) & 16u) != 0u)
                    {
                        _9968 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5051 = ((rw_nfru_diagnostics.Load<uint>(_5026 * 4 + 0) & 64u) != 0u).xxx;
                        _9968 = float3(_5051.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5051.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5051.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _9969 = _9968;
                }
                _10000 = _9969;
            }
            else
            {
                float3 _10001;
                if (_4556 == 11u)
                {
                    uint _5064 = (rw_nfru_diagnostics.Load<uint>(_5026 * 4 + 0) >> 8u) & 15u;
                    uint _5067 = (rw_nfru_diagnostics.Load<uint>(_5026 * 4 + 0) >> 12u) & 15u;
                    float3 _9961;
                    if ((_5030 == 2u) || (_5030 == 3u))
                    {
                        _9961 = _3013[_5030];
                    }
                    else
                    {
                        bool _5079 = _5064 == 3u;
                        bool _5081 = _5067 == 3u;
                        float3 _9962;
                        if (_5079 && _5081)
                        {
                            _9962 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _9963;
                            if (_5079)
                            {
                                _9963 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _9964;
                                if (_5081)
                                {
                                    _9964 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _9965;
                                    if ((_5064 == 4u) || (_5067 == 4u))
                                    {
                                        _9965 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _9966;
                                        if ((_5064 == 1u) || (_5067 == 1u))
                                        {
                                            _9966 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10220 = (_5030 == 1u).xxx;
                                            _9966 = float3(_10220.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10220.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10220.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _9965 = _9966;
                                    }
                                    _9964 = _9965;
                                }
                                _9963 = _9964;
                            }
                            _9962 = _9963;
                        }
                        _9961 = _9962;
                    }
                    _10001 = _9961;
                }
                else
                {
                    _10001 = _3013[min(_5030, 7u)];
                }
                _10000 = _10001;
            }
            _9970 = _10000;
        }
        else
        {
            _9970 = _9971;
        }
        float4 _10004;
        if ((_4556 >= 14u) && (_4556 <= 16u))
        {
            float2 _10002;
            if (_4556 == 14u)
            {
                uint _5137_dummy_parameter;
                uint _5143_dummy_parameter;
                _10002 = r_flow_tm1.Load(int3(clamp(int2(floor(_3650 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5137_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5143_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10003;
                if (_4556 == 16u)
                {
                    uint _8275 = r_warped_flow_qdata_tm1.Load(int3(_3666, 0)).x & 2147483647u;
                    uint _8307 = uint(max((int((_8275 >> 16u) & 15u) - 6), 0));
                    _10003 = ((float2(float((1 - (2 * int((_8275 >> 15u) & 1u))) * int(((_8275 >> uint(7)) & 127u) << _8307)), float((1 - (2 * int((_8275 >> 14u) & 1u))) * int((_8275 & 127u) << _8307))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10003 = _5333 * float2(cbFI_DisplaySize);
                }
                _10002 = _10003;
            }
            uint2 _5176 = uint2(clamp(round(_10002 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5178 = _5176.x;
            uint _5185 = _5176.y;
            _10004 = float4(float(_5178 & 255u), float((_5178 >> 8u) | ((_5185 & 15u) << 4u)), float(_5185 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10005;
            if (_4556 == 17u)
            {
                _10005 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3666, 0)).x != 0u), _4009, 0.0f, 1.0f);
            }
            else
            {
                _10005 = float4(_9970, 1.0f);
            }
            _10004 = _10005;
        }
        rw_output[_3300] = _10004.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5229 = ((uint(_3300.y) * uint(cbFI_DisplaySize.x)) + uint(_3300.x)) * 6u;
            uint _8353 = spvPackHalf2x16(clamp(_6037.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5229 * 4 + 0, (((_8353 & 32767u) >> 4u) | ((((_8353 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6037.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8388 = spvPackHalf2x16(clamp(_6045.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5229 + 1u) * 4 + 0, (((_8388 & 32767u) >> 4u) | ((((_8388 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6045.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8423 = spvPackHalf2x16(clamp(_6053.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5229 + 2u) * 4 + 0, (((_8423 & 32767u) >> 4u) | ((((_8423 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6053.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8458 = spvPackHalf2x16(clamp(_6061.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5229 + 3u) * 4 + 0, (((_8458 & 32767u) >> 4u) | ((((_8458 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6061.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8485 = r_current_interpolation_source.Load(int3(_3300, 0));
            uint _8499 = spvPackHalf2x16(clamp(_8485.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5229 + 4u) * 4 + 0, (((_8499 & 32767u) >> 4u) | ((((_8499 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8485.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10037;
            if (_9883 || (_4556 != 0u))
            {
                _10037 = 4294967295u;
            }
            else
            {
                uint _8534 = spvPackHalf2x16(clamp(_10004.xy, 0.0f.xx, 65000.0f.xx));
                _10037 = (((_8534 & 32767u) >> 4u) | ((((_8534 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10004.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5229 + 5u) * 4 + 0, _10037);
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
