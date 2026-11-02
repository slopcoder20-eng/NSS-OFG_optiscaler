static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3024[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3328 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3328.x >= cbFI_DisplaySize.x, _3328.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3328] = float4(r_present_backbuffer.Load(int3(_3328, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3328] = float4(r_current_interpolation_source.Load(int3(_3328, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3687 = (float2(_3328) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3698 = int2(floor(_3687 * float2(cbFI_MvDepthLaneSize)));
        int2 _3703 = int2(floor(_3687 * float2(cbFI_FlowLaneSize)));
        float4 _5385 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3687 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5391 = r_warped_filled_flow_tm1.Load(int3(_3703, 0)).xy;
        float2 _5397 = r_warped_filled_motion_tp1.Load(int3(_3698, 0)).xy;
        bool _5419 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8751;
        if (_5419)
        {
            float _5432 = ((2.0f * _3687.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8751 = float2(atan(_5432) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3687.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5432 * _5432))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8751 = _3687;
        }
        bool _3724 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8772;
        bool _8793;
        int2 _8804;
        float3 _9695;
        if (_3724)
        {
            float _8753;
            float _8755;
            _8755 = 2.0f;
            _8753 = -1.0f;
            uint _3392[9];
            float _10148;
            float _10151;
            for (int _8752 = 0; _8752 < 9; _8755 = _10151, _8753 = _10148, _8752++)
            {
                _3392[_8752] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3698 + int2((_8752 % 3) - 1, (_8752 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3392[_8752] != 0u)
                {
                    float _10143;
                    if (_3392[_8752] == 0u)
                    {
                        _10143 = -1.0f;
                    }
                    else
                    {
                        _10143 = float((_3392[_8752] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10151 = min(_8755, _10143);
                    _10148 = max(_8753, _10143);
                }
                else
                {
                    _10151 = _8755;
                    _10148 = _8753;
                }
            }
            float _3770 = float(_8753 >= 0.0f);
            float3 _8566 = 0.0f.xxx;
            _8566.y = _3770;
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
                _8771 = _5397;
                _8765 = _3698;
                _8763 = _5397;
                _8762 = _3698;
                _8761 = -1.0f;
                float _10156;
                int2 _10160;
                float2 _10171;
                int2 _10182;
                float2 _10215;
                float _10263;
                int _8760 = 0;
                float _10124 = 1000000000.0f;
                for (; _8760 < 9; _10124 = _10263, _8771 = _10215, _8765 = _10182, _8763 = _10171, _8762 = _10160, _8761 = _10156, _8760++)
                {
                    if (_3392[_8760] == 0u)
                    {
                        _10263 = _10124;
                        _10215 = _8771;
                        _10182 = _8765;
                        _10171 = _8763;
                        _10160 = _8762;
                        _10156 = _8761;
                        continue;
                    }
                    int2 _3805 = clamp(_3698 + int2((_8760 % 3) - 1, (_8760 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5507 = _3392[_8760] & 2147483647u;
                    uint _5539 = uint(max((int((_5507 >> 16u) & 15u) - 6), 0));
                    float2 _3811 = (float2(float((1 - (2 * int((_5507 >> 15u) & 1u))) * int(((_5507 >> uint(7)) & 127u) << _5539)), float((1 - (2 * int((_5507 >> 14u) & 1u))) * int((_5507 & 127u) << _5539))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10110;
                    if (_3392[_8760] == 0u)
                    {
                        _10110 = -1.0f;
                    }
                    else
                    {
                        _10110 = float((_3392[_8760] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3816 = _10110 - 0.100000001490116119384765625f;
                    float2 _10111;
                    if (_5419)
                    {
                        float2 _5616 = clamp((((_8751 + (_3811 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5619 = tan(_5616.x);
                        _10111 = (float2(_5619 / cbFI_DeviceToViewDepth.z, (tan(_5616.y) * sqrt(1.0f + (_5619 * _5619))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10111 = _8751 + (_3811 * cbFI_Timestep);
                    }
                    float _3823 = cbFI_Timestep - 1.0f;
                    float2 _10112;
                    if (_5419)
                    {
                        float2 _5687 = clamp((((_8751 + (_3811 * _3823)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5690 = tan(_5687.x);
                        _10112 = (float2(_5690 / cbFI_DeviceToViewDepth.z, (tan(_5687.y) * sqrt(1.0f + (_5690 * _5690))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10112 = _8751 + (_3811 * _3823);
                    }
                    bool _5723 = all(bool2(_10111.x > 0.0f.xx.x, _10111.y > 0.0f.xx.y));
                    bool _5729;
                    if (_5723)
                    {
                        _5729 = all(bool2(_10111.x < 1.0f.xx.x, _10111.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5729 = _5723;
                    }
                    float _10115;
                    if (_5729)
                    {
                        uint _5736_dummy_parameter;
                        _10115 = max((_3816 - (log((r_depth_tm1.Load(int3(int2(floor(_10111 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5736_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10115 = 0.0f;
                    }
                    bool _5766 = all(bool2(_10112.x > 0.0f.xx.x, _10112.y > 0.0f.xx.y));
                    bool _5772;
                    if (_5766)
                    {
                        _5772 = all(bool2(_10112.x < 1.0f.xx.x, _10112.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5772 = _5766;
                    }
                    float _10116;
                    if (_5772)
                    {
                        uint _5779_dummy_parameter;
                        _10116 = _10115 + max((_3816 - (log((r_depth_tp1.Load(int3(int2(floor(_10112 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5779_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10116 = _10115;
                    }
                    float _10157;
                    int2 _10161;
                    float2 _10172;
                    int2 _10183;
                    float2 _10216;
                    float _10264;
                    if (_10116 == 0.0f)
                    {
                        bool _3858 = _3816 > _8761;
                        bool2 _10272 = _3858.xx;
                        _10264 = _10124;
                        _10216 = float2(_10272.x ? _3811.x : _8771.x, _10272.y ? _3811.y : _8771.y);
                        _10183 = int2(_10272.x ? _3805.x : _8765.x, _10272.y ? _3805.y : _8765.y);
                        _10172 = _8763;
                        _10161 = _8762;
                        _10157 = _3858 ? _3816 : _8761;
                    }
                    else
                    {
                        bool _3867 = _10116 < _10124;
                        bool2 _10268 = _3867.xx;
                        _10264 = _3867 ? _10116 : _10124;
                        _10216 = _8771;
                        _10183 = _8765;
                        _10172 = float2(_10268.x ? _3811.x : _8763.x, _10268.y ? _3811.y : _8763.y);
                        _10161 = int2(_10268.x ? _3805.x : _8762.x, _10268.y ? _3805.y : _8762.y);
                        _10157 = _8761;
                    }
                    _10263 = _10264;
                    _10215 = _10216;
                    _10182 = _10183;
                    _10171 = _10172;
                    _10160 = _10161;
                    _10156 = _10157;
                }
                bool _3879 = _8761 < 0.0f;
                bool2 _10278 = _3879.xx;
                int2 _10281 = int2(_10278.x ? _8762.x : _8765.x, _10278.y ? _8762.y : _8765.y);
                _9696 = float3(1.0f, _3770, float(any(bool2(_10281.x != _3698.x, _10281.y != _3698.y))));
                _8805 = _10281;
                _8794 = _3879 ? false : true;
                _8773 = float2(_10278.x ? _8763.x : _8771.x, _10278.y ? _8763.y : _8771.y);
            }
            else
            {
                _9696 = _8566;
                _8805 = _3698;
                _8794 = false;
                _8773 = _5397;
            }
            _9695 = _9696;
            _8804 = _8805;
            _8793 = _8794;
            _8772 = _8773;
        }
        else
        {
            _9695 = 0.0f.xxx;
            _8804 = _3698;
            _8793 = false;
            _8772 = _5397;
        }
        float2 _8774;
        if (_5419)
        {
            float2 _5844 = clamp((((_8751 + (_8772 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5847 = tan(_5844.x);
            _8774 = (float2(_5847 / cbFI_DeviceToViewDepth.z, (tan(_5844.y) * sqrt(1.0f + (_5847 * _5847))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8774 = _8751 + (_8772 * cbFI_Timestep);
        }
        float _3902 = cbFI_Timestep - 1.0f;
        float2 _8776;
        if (_5419)
        {
            float2 _5915 = clamp((((_8751 + (_8772 * _3902)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5918 = tan(_5915.x);
            _8776 = (float2(_5918 / cbFI_DeviceToViewDepth.z, (tan(_5915.y) * sqrt(1.0f + (_5918 * _5918))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8776 = _8751 + (_8772 * _3902);
        }
        float _3907 = -cbFI_Timestep;
        float2 _8777;
        if (_5419)
        {
            float2 _5986 = clamp((((_8751 + (_5391 * _3907)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5989 = tan(_5986.x);
            _8777 = (float2(_5989 / cbFI_DeviceToViewDepth.z, (tan(_5986.y) * sqrt(1.0f + (_5989 * _5989))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8777 = _8751 + (_5391 * _3907);
        }
        float _3912 = 1.0f - cbFI_Timestep;
        float2 _8778;
        if (_5419)
        {
            float2 _6057 = clamp((((_8751 + (_5391 * _3912)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6060 = tan(_6057.x);
            _8778 = (float2(_6060 / cbFI_DeviceToViewDepth.z, (tan(_6057.y) * sqrt(1.0f + (_6060 * _6060))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8778 = _8751 + (_5391 * _3912);
        }
        float4 _6095 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8774, 0.0f);
        float3 _6096 = _6095.xyz;
        float4 _6103 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8776, 0.0f);
        float3 _6104 = _6103.xyz;
        float4 _6111 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8777, 0.0f);
        float3 _6112 = _6111.xyz;
        float4 _6119 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8778, 0.0f);
        float3 _6120 = _6119.xyz;
        float4 _6134 = exp(_5385 - max(max(max(_5385.x, _5385.y), _5385.z), _5385.w).xxxx);
        float4 _6141 = _6134 / (dot(_6134, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3931 = _3724 && (!_8793);
        bool _3940;
        if (_3931)
        {
            _3940 = (_6141.z + _6141.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3940 = _3931;
        }
        bool _3951;
        if (_3940)
        {
            _3951 = length((_8777 - _8774) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _3951 = _3940;
        }
        bool _8817;
        if (_3951)
        {
            uint4 _6160 = r_warped_motion_qdata_tp1.Load(int3(_8804, 0));
            uint _6161 = _6160.x;
            bool _8820;
            if (_6161 != 0u)
            {
                float _8806;
                if (_6161 == 0u)
                {
                    _8806 = -1.0f;
                }
                else
                {
                    _8806 = float((_6161 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _3961 = _8806 - 0.12000000476837158203125f;
                bool _6180 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                bool _6186;
                if (_6180)
                {
                    _6186 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                }
                else
                {
                    _6186 = _6180;
                }
                bool _3971;
                if (_6186)
                {
                    uint _6193_dummy_parameter;
                    _3971 = (log((r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6193_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3961;
                }
                else
                {
                    _3971 = _6186;
                }
                bool _3985;
                if (!_3971)
                {
                    bool _6223 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                    bool _6229;
                    if (_6223)
                    {
                        _6229 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6229 = _6223;
                    }
                    bool _3983;
                    if (_6229)
                    {
                        uint _6236_dummy_parameter;
                        _3983 = (log((r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6236_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _3961;
                    }
                    else
                    {
                        _3983 = _6229;
                    }
                    _3985 = _3983;
                }
                else
                {
                    _3985 = _3971;
                }
                _8820 = _3985;
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
        bool _3990 = _8793 || _8817;
        bool _3995;
        if (_3990)
        {
            bool _6266 = all(bool2(_8774.x > 0.0f.xx.x, _8774.y > 0.0f.xx.y));
            bool _6272;
            if (_6266)
            {
                _6272 = all(bool2(_8774.x < 1.0f.xx.x, _8774.y < 1.0f.xx.y));
            }
            else
            {
                _6272 = _6266;
            }
            _3995 = _6272;
        }
        else
        {
            _3995 = _3990;
        }
        bool _4000;
        if (_3995)
        {
            bool _6277 = all(bool2(_8776.x > 0.0f.xx.x, _8776.y > 0.0f.xx.y));
            bool _6283;
            if (_6277)
            {
                _6283 = all(bool2(_8776.x < 1.0f.xx.x, _8776.y < 1.0f.xx.y));
            }
            else
            {
                _6283 = _6277;
            }
            _4000 = _6283;
        }
        else
        {
            _4000 = _3995;
        }
        float4 _8911;
        if (_4000)
        {
            float _4003 = _6141.x;
            float _4005 = _6141.y;
            float _4006 = _4003 + _4005;
            float _4011 = _6141.z + _6141.w;
            float _8835;
            if (_4006 > 0.001000000047497451305389404296875f)
            {
                _8835 = _4003 / _4006;
            }
            else
            {
                _8835 = _3912;
            }
            _8911 = float4(_4003 + (_4011 * _8835), _4005 + (_4011 * (1.0f - _8835)), 0.0f, 0.0f);
        }
        else
        {
            _8911 = _6141;
        }
        bool _6311 = (cbFI_pad0 & 1024u) != 0u;
        bool _6287 = !_6311;
        bool _6288 = !_6287;
        bool _6305;
        if (_6288)
        {
            _6305 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_8804.y * cbFI_MvDepthLaneSize.x) + _8804.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6305 = _6287;
        }
        bool _6337;
        if (_6288)
        {
            _6337 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3703.y * cbFI_FlowLaneSize.x) + _3703.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6337 = _6287;
        }
        float _4046 = float(_6337);
        bool _8923;
        float4 _8953;
        float3 _9555;
        if (_6311)
        {
            bool _4056;
            if (_6305)
            {
                _4056 = all(bool2(_8774.x > 0.0f.xx.x, _8774.y > 0.0f.xx.y));
            }
            else
            {
                _4056 = _6305;
            }
            bool _4062;
            if (_4056)
            {
                _4062 = all(bool2(_8774.x < 1.0f.xx.x, _8774.y < 1.0f.xx.y));
            }
            else
            {
                _4062 = _4056;
            }
            bool _4069;
            if (_6305)
            {
                _4069 = all(bool2(_8776.x > 0.0f.xx.x, _8776.y > 0.0f.xx.y));
            }
            else
            {
                _4069 = _6305;
            }
            bool _4075;
            if (_4069)
            {
                _4075 = all(bool2(_8776.x < 1.0f.xx.x, _8776.y < 1.0f.xx.y));
            }
            else
            {
                _4075 = _4069;
            }
            bool _4082;
            if (_6337)
            {
                _4082 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
            }
            else
            {
                _4082 = _6337;
            }
            bool _4088;
            if (_4082)
            {
                _4088 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
            }
            else
            {
                _4088 = _4082;
            }
            bool _4095;
            if (_6337)
            {
                _4095 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
            }
            else
            {
                _4095 = _6337;
            }
            bool _4101;
            if (_4095)
            {
                _4101 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
            }
            else
            {
                _4101 = _4095;
            }
            bool _4103 = !_6305;
            if (_4103)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6379;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6379);
                }
            }
            bool _4108 = !_6337;
            if (_4108)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6389;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6389);
                }
            }
            if (_6305 && _4108)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6399;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6399);
                }
            }
            if (_4103 && _6337)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6409;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6409);
                }
            }
            float _4127 = float(_4062);
            float _4129 = float(_4075);
            bool _4132 = _4088 && _4101;
            float _8869;
            if (_4132)
            {
                _8869 = 1.0f;
            }
            else
            {
                _8869 = (_4088 || _4101) ? 0.5f : 0.0f;
            }
            bool _8874;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4062)) && (!_4075))
            {
                bool _4162;
                if (_4132)
                {
                    float _8872;
                    do
                    {
                        bool _6493 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                        bool _6499;
                        if (_6493)
                        {
                            _6499 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6499 = _6493;
                        }
                        bool _6430 = !_6499;
                        bool _6437;
                        if (!_6430)
                        {
                            bool _6504 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                            bool _6510;
                            if (_6504)
                            {
                                _6510 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6510 = _6504;
                            }
                            _6437 = !_6510;
                        }
                        else
                        {
                            _6437 = _6430;
                        }
                        if (_6437)
                        {
                            _8872 = 0.0f;
                            break;
                        }
                        uint _6517_dummy_parameter;
                        uint _6533_dummy_parameter;
                        float4 _6458 = mul(float4((float2(_8777.x, 1.0f - _8777.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6517_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6460 = _6458.w;
                        if (abs(_6460) < 9.9999999747524270787835121154785e-07f)
                        {
                            _8872 = 0.0f;
                            break;
                        }
                        float _6471 = abs(cbFI_DeviceToViewDepth.y / ((_6458.z / _6460) - cbFI_DeviceToViewDepth.x));
                        float _6474 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6533_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _8872 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6471 - _6474) / max(max(_6471, _6474), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4162 = _8872 >= 0.5f;
                }
                else
                {
                    _4162 = _4132;
                }
                bool _8875;
                if (_4162)
                {
                    uint _6583_dummy_parameter;
                    float2 _8873;
                    do
                    {
                        float _6609 = 1.0f - _8777.y;
                        float4 _6620 = mul(float4((float2(_8777.x, _6609) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6583_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6622 = _6620.w;
                        if (!(_6622 > 9.9999999747524270787835121154785e-07f))
                        {
                            _8873 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6635 = ((_6620.xy / _6622.xx) + 1.0f.xx) * 0.5f;
                        _8873 = float2(_6635.x - _8777.x, _6609 - _6635.y);
                        break;
                    } while(false);
                    float2 _4176 = float2(cbFI_DisplaySize);
                    _8875 = length(((_8777 + _8873) - _8778) * _4176) <= ((0.100000001490116119384765625f * length(_8873 * _4176)) + 8.0f);
                }
                else
                {
                    _8875 = _4162;
                }
                _8874 = _8875;
            }
            else
            {
                _8874 = true;
            }
            bool _4190 = !_8874;
            bool _10282 = _4190 ? false : _4101;
            bool _10283 = _4190 ? false : _4088;
            bool _8924;
            float4 _8954;
            if (!(((_4062 && _4075) && _10283) && _10282))
            {
                float4 _4212 = _8911 * float4(_4127, _4129, float(_10283), float(_10282));
                float _4214 = dot(_4212, 1.0f.xxxx);
                bool _4217 = !(_4214 > 0.0f);
                float4 _8955;
                if (!_4217)
                {
                    _8955 = _4212 / _4214.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6657;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6657);
                    }
                    _8955 = 0.0f.xxxx;
                }
                _8954 = _8955;
                _8924 = _4217;
            }
            else
            {
                _8954 = _8911;
                _8924 = false;
            }
            _9555 = float3(_4127, _4129, _8869);
            _8953 = _8954;
            _8923 = _8924;
        }
        else
        {
            _9555 = float3(float(_6305), _4046, 0.0f);
            _8953 = _8911;
            _8923 = false;
        }
        float4 _9425;
        bool _9445;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_8923))
        {
            bool _4240 = _8953.x > 0.00999999977648258209228515625f;
            bool _4243 = _8953.y > 0.00999999977648258209228515625f;
            bool _4252 = (_8953.z + _8953.w) > 0.0199999995529651641845703125f;
            bool _4258;
            if (_4252)
            {
                bool _6663 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                bool _6669;
                if (_6663)
                {
                    _6669 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                }
                else
                {
                    _6669 = _6663;
                }
                _4258 = _6669;
            }
            else
            {
                _4258 = _4252;
            }
            bool _4263;
            if (_4258)
            {
                bool _6674 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                bool _6680;
                if (_6674)
                {
                    _6680 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                }
                else
                {
                    _6680 = _6674;
                }
                _4263 = _6680;
            }
            else
            {
                _4263 = _4258;
            }
            bool _4270;
            if (_4263)
            {
                float _8957;
                do
                {
                    bool _6763 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                    bool _6769;
                    if (_6763)
                    {
                        _6769 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6769 = _6763;
                    }
                    bool _6700 = !_6769;
                    bool _6707;
                    if (!_6700)
                    {
                        bool _6774 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                        bool _6780;
                        if (_6774)
                        {
                            _6780 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6780 = _6774;
                        }
                        _6707 = !_6780;
                    }
                    else
                    {
                        _6707 = _6700;
                    }
                    if (_6707)
                    {
                        _8957 = 0.0f;
                        break;
                    }
                    uint _6787_dummy_parameter;
                    uint _6803_dummy_parameter;
                    float4 _6728 = mul(float4((float2(_8777.x, 1.0f - _8777.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6787_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6730 = _6728.w;
                    if (abs(_6730) < 9.9999999747524270787835121154785e-07f)
                    {
                        _8957 = 0.0f;
                        break;
                    }
                    float _6741 = abs(cbFI_DeviceToViewDepth.y / ((_6728.z / _6730) - cbFI_DeviceToViewDepth.x));
                    float _6744 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6803_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _8957 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6741 - _6744) / max(max(_6741, _6744), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4270 = _8957 < 0.5f;
            }
            else
            {
                _4270 = _4263;
            }
            float4 _8972;
            if (_4270)
            {
                uint _6853_dummy_parameter;
                uint _6884_dummy_parameter;
                float4 _8973;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6853_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6884_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
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
            bool _4294;
            if (_6305)
            {
                bool _6913 = all(bool2(_8774.x > 0.0f.xx.x, _8774.y > 0.0f.xx.y));
                bool _6919;
                if (_6913)
                {
                    _6919 = all(bool2(_8774.x < 1.0f.xx.x, _8774.y < 1.0f.xx.y));
                }
                else
                {
                    _6919 = _6913;
                }
                _4294 = _6919;
            }
            else
            {
                _4294 = _6305;
            }
            bool _4300;
            if (_6305)
            {
                bool _6924 = all(bool2(_8776.x > 0.0f.xx.x, _8776.y > 0.0f.xx.y));
                bool _6930;
                if (_6924)
                {
                    _6930 = all(bool2(_8776.x < 1.0f.xx.x, _8776.y < 1.0f.xx.y));
                }
                else
                {
                    _6930 = _6924;
                }
                _4300 = _6930;
            }
            else
            {
                _4300 = _6305;
            }
            bool _4306;
            if (_6337)
            {
                bool _6935 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                bool _6941;
                if (_6935)
                {
                    _6941 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                }
                else
                {
                    _6941 = _6935;
                }
                _4306 = _6941;
            }
            else
            {
                _4306 = _6337;
            }
            bool _4312;
            if (_6337)
            {
                bool _6946 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                bool _6952;
                if (_6946)
                {
                    _6952 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                }
                else
                {
                    _6952 = _6946;
                }
                _4312 = _6952;
            }
            else
            {
                _4312 = _6337;
            }
            bool _4315 = _4306 != _4312;
            bool _4321;
            if (_4315)
            {
                _4321 = _4294 || _4300;
            }
            else
            {
                _4321 = _4315;
            }
            float4 _9075;
            if (_4321)
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
            bool _4328 = _4294 && _4240;
            bool _4331 = _4300 && _4243;
            float4 _9150;
            if (_4328 || _4331)
            {
                float _9049;
                do
                {
                    uint4 _7091 = r_warped_motion_qdata_tp1.Load(int3(_8804, 0));
                    uint _7092 = _7091.x;
                    if (_7092 != 0u)
                    {
                        float _9048;
                        if (_7092 == 0u)
                        {
                            _9048 = -1.0f;
                        }
                        else
                        {
                            _9048 = float((_7092 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9049 = _9048;
                        break;
                    }
                    int _9031;
                    uint _9032;
                    _9032 = _7092;
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
                    uint _10252;
                    for (int _9033 = 0; _9033 < 8; _9034 = _10252, _9033++)
                    {
                        int _9037 = 0;
                        for (;;)
                        {
                            if (_9037 < 5)
                            {
                                int2 _7042 = _8804 + (_1093[_9033] * _1102[_9037].xx);
                                bool _7045 = any(bool2(_7042.x < int2(0, 0).x, _7042.y < int2(0, 0).y));
                                bool _7053;
                                if (!_7045)
                                {
                                    _7053 = any(bool2(_7042.x >= cbFI_MvDepthLaneSize.x, _7042.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7053 = _7045;
                                }
                                if (_7053)
                                {
                                    _10252 = _9034;
                                    break;
                                }
                                uint4 _7131 = r_warped_motion_qdata_tp1.Load(int3(_7042, 0));
                                uint _7132 = _7131.x;
                                if (_7132 != 0u)
                                {
                                    _10252 = min(_9034, _7132);
                                    break;
                                }
                                _9037++;
                                continue;
                            }
                            else
                            {
                                _10252 = _9034;
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
                float _4342 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4344 = _9049 >= 0.0f;
                float _9056;
                if (_4344)
                {
                    _9056 = _9049 - _4342;
                }
                else
                {
                    float _9052;
                    if (_4328)
                    {
                        float _9051;
                        _9051 = 2.0f;
                        float _7203;
                        for (int _9050 = 0; _9050 < 24; _9051 = _7203, _9050++)
                        {
                            float _7167 = float(_9050 & 7) * 0.785398185253143310546875f;
                            int _7169 = _9050 >> 3;
                            int _9053;
                            if (_7169 == 0)
                            {
                                _9053 = 16;
                            }
                            else
                            {
                                _9053 = (_7169 == 1) ? 48 : 96;
                            }
                            uint _7219_dummy_parameter;
                            _7203 = min(_9051, log((r_depth_tm1.Load(int3(int2(floor(clamp(_8774 + ((cbFI_MvDepthLaneSizeRcp * float(_9053)) * float2(cos(_7167), sin(_7167))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7219_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
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
                if (_4344)
                {
                    _9063 = _9049 - _4342;
                }
                else
                {
                    float _9059;
                    if (_4331)
                    {
                        float _9058;
                        _9058 = 2.0f;
                        float _7317;
                        for (int _9057 = 0; _9057 < 24; _9058 = _7317, _9057++)
                        {
                            float _7281 = float(_9057 & 7) * 0.785398185253143310546875f;
                            int _7283 = _9057 >> 3;
                            int _9060;
                            if (_7283 == 0)
                            {
                                _9060 = 16;
                            }
                            else
                            {
                                _9060 = (_7283 == 1) ? 48 : 96;
                            }
                            uint _7349_dummy_parameter;
                            _7317 = min(_9058, log((r_depth_tp1.Load(int3(int2(floor(clamp(_8776 + ((cbFI_MvDepthLaneSizeRcp * float(_9060)) * float2(cos(_7281), sin(_7281))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7349_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
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
                if (_4328)
                {
                    uint _7381_dummy_parameter;
                    _9064 = r_depth_tm1.Load(int3(int2(floor(_8774 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7381_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9064 = 0.0f;
                }
                float _9065;
                if (_4331)
                {
                    uint _7400_dummy_parameter;
                    _9065 = r_depth_tp1.Load(int3(int2(floor(_8776 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7400_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9065 = 0.0f;
                }
                bool _4399;
                if (_4328)
                {
                    _4399 = _9064 > ((exp((_9056 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4399 = _4328;
                }
                float4 _9090;
                if (_4399)
                {
                    float4 _8655 = _9075;
                    _8655.x = 0.0f;
                    _9090 = _8655;
                }
                else
                {
                    _9090 = _9075;
                }
                bool _4411;
                if (_4331)
                {
                    _4411 = _9065 > ((exp((_9063 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4411 = _4331;
                }
                float4 _9092;
                if (_4411)
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
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4344)
                {
                    bool _4431;
                    if (_4328)
                    {
                        _4431 = _9064 < ((exp((_9056 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4431 = _4328;
                    }
                    float4 _9094;
                    if (_4431)
                    {
                        float4 _8659 = _9092;
                        _8659.x = 0.0f;
                        _9094 = _8659;
                    }
                    else
                    {
                        _9094 = _9092;
                    }
                    bool _4443;
                    if (_4331)
                    {
                        _4443 = _9065 < ((exp((_9063 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4443 = _4331;
                    }
                    float4 _9152;
                    if (_4443)
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
            bool _4454 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4252;
            bool _4460;
            if (_4454)
            {
                _4460 = _4306 || _4312;
            }
            else
            {
                _4460 = _4454;
            }
            float4 _9172;
            if (_4460)
            {
                float _9145;
                do
                {
                    uint4 _7579 = r_warped_motion_qdata_tp1.Load(int3(_8804, 0));
                    uint _7580 = _7579.x;
                    if (_7580 != 0u)
                    {
                        float _9144;
                        if (_7580 == 0u)
                        {
                            _9144 = -1.0f;
                        }
                        else
                        {
                            _9144 = float((_7580 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9145 = _9144;
                        break;
                    }
                    int _9127;
                    uint _9128;
                    _9128 = _7580;
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
                    uint _10253;
                    for (int _9129 = 0; _9129 < 8; _9130 = _10253, _9129++)
                    {
                        int _9133 = 0;
                        for (;;)
                        {
                            if (_9133 < 5)
                            {
                                int2 _7530 = _8804 + (_1093[_9129] * _1102[_9133].xx);
                                bool _7533 = any(bool2(_7530.x < int2(0, 0).x, _7530.y < int2(0, 0).y));
                                bool _7541;
                                if (!_7533)
                                {
                                    _7541 = any(bool2(_7530.x >= cbFI_MvDepthLaneSize.x, _7530.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7541 = _7533;
                                }
                                if (_7541)
                                {
                                    _10253 = _9130;
                                    break;
                                }
                                uint4 _7619 = r_warped_motion_qdata_tp1.Load(int3(_7530, 0));
                                uint _7620 = _7619.x;
                                if (_7620 != 0u)
                                {
                                    _10253 = min(_9130, _7620);
                                    break;
                                }
                                _9133++;
                                continue;
                            }
                            else
                            {
                                _10253 = _9130;
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
                    float _7641 = (exp((_9145 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4479;
                    if (_4306)
                    {
                        uint _7648_dummy_parameter;
                        _4479 = r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7648_dummy_parameter))))), 0)).x > _7641;
                    }
                    else
                    {
                        _4479 = _4306;
                    }
                    float4 _9163;
                    if (_4479)
                    {
                        float4 _8663 = _9150;
                        _8663.z = 0.0f;
                        _9163 = _8663;
                    }
                    else
                    {
                        _9163 = _9150;
                    }
                    bool _4491;
                    if (_4312)
                    {
                        uint _7667_dummy_parameter;
                        _4491 = r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7667_dummy_parameter))))), 0)).x > _7641;
                    }
                    else
                    {
                        _4491 = _4312;
                    }
                    float4 _9174;
                    if (_4491)
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
            bool _4499 = _4294 != _4300;
            bool _4506;
            if (_4499)
            {
                _4506 = _4294 ? _4240 : _4243;
            }
            else
            {
                _4506 = _4499;
            }
            float4 _9252;
            if (_4506)
            {
                bool2 _4511 = _4294.xx;
                float2 _4512 = float2(_4511.x ? _8774.x : _8776.x, _4511.y ? _8774.y : _8776.y);
                float _9165;
                if (_4294)
                {
                    uint _7686_dummy_parameter;
                    _9165 = r_depth_tm1.Load(int3(int2(floor(_4512 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7686_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7702_dummy_parameter;
                    _9165 = r_depth_tp1.Load(int3(int2(floor(_4512 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7702_dummy_parameter))))), 0)).x;
                }
                float4x4 _9166;
                if (_4294)
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
                    float _7729 = _4512.x;
                    float _7732 = 1.0f - _4512.y;
                    float4 _7743 = mul(float4((float2(_7729, _7732) * 2.0f) - 1.0f.xx, _9165, 1.0f), _9166);
                    float _7745 = _7743.w;
                    if (!(_7745 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9167 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7758 = ((_7743.xy / _7745.xx) + 1.0f.xx) * 0.5f;
                    _9167 = float2(_7758.x - _7729, _7732 - _7758.y);
                    break;
                } while(false);
                float2 _4542 = float2(cbFI_DisplaySize);
                float4 _9253;
                if (!(length(((_4512 + _9167) - float2(_4511.x ? _8776.x : _8774.x, _4511.y ? _8776.y : _8774.y)) * _4542) <= ((0.100000001490116119384765625f * length(_9167 * _4542)) + 8.0f)))
                {
                    float4 _9254;
                    if (_4294)
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
            float4 _4567 = _8953 * _9252;
            float _4569 = dot(_4567, 1.0f.xxxx);
            float4 _9426;
            bool _9446;
            if (_4569 > 0.0f)
            {
                _9446 = _8923;
                _9426 = _4567 / _4569.xxxx;
            }
            else
            {
                bool _4580 = any(bool4(_9252.x < 1.0f.xxxx.x, _9252.y < 1.0f.xxxx.y, _9252.z < 1.0f.xxxx.z, _9252.w < 1.0f.xxxx.w));
                if (_4580)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7780;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7780);
                    }
                }
                bool4 _10285 = _4580.xxxx;
                _9446 = _4580 ? true : _8923;
                _9426 = float4(_10285.x ? 0.0f.xxxx.x : _8953.x, _10285.y ? 0.0f.xxxx.y : _8953.y, _10285.z ? 0.0f.xxxx.z : _8953.z, _10285.w ? 0.0f.xxxx.w : _8953.w);
            }
            _9445 = _9446;
            _9425 = _9426;
        }
        else
        {
            _9445 = _8923;
            _9425 = _8953;
        }
        uint _4589 = (cbFI_pad0 >> 24u) & 31u;
        uint _4593 = (cbFI_pad0 >> 16u) & 255u;
        bool _4595 = _4589 != 0u;
        bool _4597 = _4593 == 12u;
        bool _4600 = _4593 == 13u;
        float4 _9442;
        float _9848;
        float _9875;
        float _9901;
        if ((_4595 || _4597) || _4600)
        {
            float _9255;
            do
            {
                bool _7864 = all(bool2(_8777.x > 0.0f.xx.x, _8777.y > 0.0f.xx.y));
                bool _7870;
                if (_7864)
                {
                    _7870 = all(bool2(_8777.x < 1.0f.xx.x, _8777.y < 1.0f.xx.y));
                }
                else
                {
                    _7870 = _7864;
                }
                bool _7801 = !_7870;
                bool _7808;
                if (!_7801)
                {
                    bool _7875 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
                    bool _7881;
                    if (_7875)
                    {
                        _7881 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7881 = _7875;
                    }
                    _7808 = !_7881;
                }
                else
                {
                    _7808 = _7801;
                }
                if (_7808)
                {
                    _9255 = 0.0f;
                    break;
                }
                uint _7888_dummy_parameter;
                uint _7904_dummy_parameter;
                float4 _7829 = mul(float4((float2(_8777.x, 1.0f - _8777.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8777 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7888_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7831 = _7829.w;
                if (abs(_7831) < 9.9999999747524270787835121154785e-07f)
                {
                    _9255 = 0.0f;
                    break;
                }
                float _7842 = abs(cbFI_DeviceToViewDepth.y / ((_7829.z / _7831) - cbFI_DeviceToViewDepth.x));
                float _7845 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7904_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9255 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7842 - _7845) / max(max(_7842, _7845), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _7952 = all(bool2(_8778.x > 0.0f.xx.x, _8778.y > 0.0f.xx.y));
            bool _7958;
            if (_7952)
            {
                _7958 = all(bool2(_8778.x < 1.0f.xx.x, _8778.y < 1.0f.xx.y));
            }
            else
            {
                _7958 = _7952;
            }
            float _9256;
            if (_7958)
            {
                uint _7965_dummy_parameter;
                _9256 = length((_5391 + (r_motion_tp1.Load(int3(int2(floor(_8778 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7965_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9256 = 1000000.0f;
            }
            float _4620 = 1.0f - smoothstep(2.0f, 8.0f, _9256);
            float _9267;
            if ((_4589 & 1u) != 0u)
            {
                _9267 = _9255;
            }
            else
            {
                _9267 = 1.0f;
            }
            float _9268;
            if ((_4589 & 2u) != 0u)
            {
                _9268 = _9267 * _4620;
            }
            else
            {
                _9268 = _9267;
            }
            float _9269;
            if ((_4589 & 4u) != 0u)
            {
                _9269 = _9268 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6112 - _6120) - length(_6096 - _6104))));
            }
            else
            {
                _9269 = _9268;
            }
            float _9436;
            if ((_4589 & 8u) != 0u)
            {
                _9436 = lerp(1.0f, _9269, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6096 - _6104)));
            }
            else
            {
                _9436 = _9269;
            }
            bool _4675 = (_4589 & 16u) != 0u;
            bool _4684;
            if (_4675)
            {
                _4684 = length(_8772 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4684 = _4675;
            }
            float _10287 = _4684 ? 1.0f : _9436;
            bool _4690 = _4595 && _6305;
            bool _4695;
            if (_4690)
            {
                bool _7990 = all(bool2(_8774.x > 0.0f.xx.x, _8774.y > 0.0f.xx.y));
                bool _7996;
                if (_7990)
                {
                    _7996 = all(bool2(_8774.x < 1.0f.xx.x, _8774.y < 1.0f.xx.y));
                }
                else
                {
                    _7996 = _7990;
                }
                _4695 = _7996;
            }
            else
            {
                _4695 = _4690;
            }
            bool _4700;
            if (_4695)
            {
                bool _8001 = all(bool2(_8776.x > 0.0f.xx.x, _8776.y > 0.0f.xx.y));
                bool _8007;
                if (_8001)
                {
                    _8007 = all(bool2(_8776.x < 1.0f.xx.x, _8776.y < 1.0f.xx.y));
                }
                else
                {
                    _8007 = _8001;
                }
                _4700 = _8007;
            }
            else
            {
                _4700 = _4695;
            }
            float4 _9443;
            if (_4700)
            {
                float _4706 = _9425.x + _9425.y;
                float _4715 = (_9425.z + _9425.w) * (1.0f - _10287);
                float _9439;
                if (_4706 > 9.9999997473787516355514526367188e-06f)
                {
                    _9439 = _9425.x / _4706;
                }
                else
                {
                    _9439 = _3912;
                }
                _9443 = float4(_9425.x + (_4715 * _9439), _9425.y + (_4715 * (1.0f - _9439)), _9425.zw * _10287);
            }
            else
            {
                _9443 = _9425;
            }
            _9901 = _10287;
            _9875 = _4620;
            _9848 = _9255;
            _9442 = _9443;
        }
        else
        {
            _9901 = 1.0f;
            _9875 = 1.0f;
            _9848 = 1.0f;
            _9442 = _9425;
        }
        float3 _10057;
        if (_9445)
        {
            float3 _8013 = r_current_interpolation_source.Load(int3(_3328, 0)).xyz;
            float3 _10058;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6305)
            {
                uint _8020_dummy_parameter;
                float _9545;
                _9545 = r_depth_tm1.Load(int3(int2(floor(_8774 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8020_dummy_parameter))))), 0)).x;
                float _4827;
                for (int _9544 = 0; _9544 < 24; _9545 = _4827, _9544++)
                {
                    float _4799 = float(_9544 & 7) * 0.785398185253143310546875f;
                    int _4801 = _9544 >> 3;
                    int _10107;
                    if (_4801 == 0)
                    {
                        _10107 = 16;
                    }
                    else
                    {
                        _10107 = (_4801 == 1) ? 48 : 96;
                    }
                    uint _8040_dummy_parameter;
                    _4827 = min(_9545, r_depth_tm1.Load(int3(int2(floor(clamp(_8774 + ((cbFI_MvDepthLaneSizeRcp * float(_10107)) * float2(cos(_4799), sin(_4799))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8040_dummy_parameter))))), 0)).x);
                }
                float2 _9546;
                do
                {
                    float _8062 = 1.0f - _8774.y;
                    float4 _8073 = mul(float4((float2(_8774.x, _8062) * 2.0f) - 1.0f.xx, _9545, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8075 = _8073.w;
                    if (!(_8075 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9546 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8088 = ((_8073.xy / _8075.xx) + 1.0f.xx) * 0.5f;
                    _9546 = float2(_8088.x - _8774.x, _8062 - _8088.y);
                    break;
                } while(false);
                float2 _4838 = _8774 + _9546;
                bool _8106 = all(bool2(_4838.x > 0.0f.xx.x, _4838.y > 0.0f.xx.y));
                bool _8112;
                if (_8106)
                {
                    _8112 = all(bool2(_4838.x < 1.0f.xx.x, _4838.y < 1.0f.xx.y));
                }
                else
                {
                    _8112 = _8106;
                }
                float3 _10059;
                if (_8112)
                {
                    float _4844 = abs(cbFI_DeviceToViewDepth.y / (_9545 - cbFI_DeviceToViewDepth.x));
                    uint _8132_dummy_parameter;
                    int2 _8132 = int2(spvTextureSize(r_depth_m2, uint(0), _8132_dummy_parameter));
                    float _4848 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4838 * float2(_8132))), int2(0, 0), _8132 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10064;
                    if (abs(_4848 - _4844) <= (0.20000000298023223876953125f * max(_4848, _4844)))
                    {
                        uint _8166_dummy_parameter;
                        int2 _8166 = int2(spvTextureSize(r_colour_m2, uint(0), _8166_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8189;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8189);
                        }
                        _10064 = r_colour_m2.Load(int3(clamp(int2(floor(_4838 * float2(_8166))), int2(0, 0), _8166 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8199;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8199);
                        }
                        _10064 = _8013;
                    }
                    _10059 = _10064;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8209;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8209);
                    }
                    _10059 = _8013;
                }
                _10058 = _10059;
            }
            else
            {
                _10058 = _8013;
            }
            _10057 = _10058;
        }
        else
        {
            _10057 = (((_6096 * _9442.x) + (_6104 * _9442.y)) + (_6112 * _9442.z)) + (_6120 * _9442.w);
        }
        uint _4876 = cbFI_pad0 & 255u;
        bool _9952;
        float3 _10056;
        if (_4876 != 0u)
        {
            float3 _4881 = r_present_backbuffer.Load(int3(_3328, 0)).xyz;
            float3 _4885 = r_current_interpolation_source.Load(int3(_3328, 0)).xyz;
            float3 _4889 = abs(_4881 - _4885);
            float3 _9549;
            if (_4876 == 2u)
            {
                _9549 = (abs(_4885) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9549 = 0.000244140625f.xxx;
            }
            bool _4905 = any(bool3(_4889.x > _9549.x, _4889.y > _9549.y, _4889.z > _9549.z));
            bool3 _10288 = _4905.xxx;
            _10056 = float3(_10288.x ? _4881.x : _10057.x, _10288.y ? _4881.y : _10057.y, _10288.z ? _4881.z : _10057.z);
            _9952 = _4905;
        }
        else
        {
            _10056 = _10057;
            _9952 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8224;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8224);
        }
        float3 _10040;
        if (_4593 == 1u)
        {
            _10040 = lerp(_6096, _6104, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10041;
            if (_4593 == 2u)
            {
                _10041 = lerp(_6112, _6120, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10042;
                if (_4593 == 3u)
                {
                    _10042 = float(_9952).xxx;
                }
                else
                {
                    float3 _10043;
                    if (_4593 == 4u)
                    {
                        _10043 = float3(((_8772 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10044;
                        if (_4593 == 5u)
                        {
                            _10044 = float3(((_5391 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10045;
                            if (_4593 == 6u)
                            {
                                _10045 = float3(_9442.xy, _9442.z + _9442.w);
                            }
                            else
                            {
                                float3 _10046;
                                if (_4593 == 7u)
                                {
                                    _10046 = r_current_interpolation_source.Load(int3(_3328, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10047;
                                    if (_4593 == 8u)
                                    {
                                        _10047 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3687, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10048;
                                        if (_4597)
                                        {
                                            _10048 = float3(_9848, _9875, _9901);
                                        }
                                        else
                                        {
                                            float3 _10049;
                                            if (_4600)
                                            {
                                                _10049 = _6112;
                                            }
                                            else
                                            {
                                                float3 _10050;
                                                if (_4593 == 20u)
                                                {
                                                    _10050 = _6096;
                                                }
                                                else
                                                {
                                                    float3 _10051;
                                                    if (_4593 == 21u)
                                                    {
                                                        _10051 = _6104;
                                                    }
                                                    else
                                                    {
                                                        float3 _10052;
                                                        if (_4593 == 22u)
                                                        {
                                                            _10052 = _6120;
                                                        }
                                                        else
                                                        {
                                                            float3 _10053;
                                                            if (_4593 == 18u)
                                                            {
                                                                _10053 = _9695;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10290 = (_4593 == 19u).xxx;
                                                                _10053 = float3(_10290.x ? _9555.x : _10056.x, _10290.y ? _9555.y : _10056.y, _10290.z ? _9555.z : _10056.z);
                                                            }
                                                            _10052 = _10053;
                                                        }
                                                        _10051 = _10052;
                                                    }
                                                    _10050 = _10051;
                                                }
                                                _10049 = _10050;
                                            }
                                            _10048 = _10049;
                                        }
                                        _10047 = _10048;
                                    }
                                    _10046 = _10047;
                                }
                                _10045 = _10046;
                            }
                            _10044 = _10045;
                        }
                        _10043 = _10044;
                    }
                    _10042 = _10043;
                }
                _10041 = _10042;
            }
            _10040 = _10041;
        }
        float3 _10039;
        if ((_4593 >= 9u) && (_4593 <= 11u))
        {
            uint _5060 = 64u + uint((_8804.y * cbFI_MvDepthLaneSize.x) + _8804.x);
            uint _5064 = rw_nfru_diagnostics.Load<uint>(_5060 * 4 + 0) & 15u;
            float3 _10069;
            if (_4593 == 10u)
            {
                float3 _10038;
                if ((rw_nfru_diagnostics.Load<uint>(_5060 * 4 + 0) & 32u) != 0u)
                {
                    _10038 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10037;
                    if ((rw_nfru_diagnostics.Load<uint>(_5060 * 4 + 0) & 16u) != 0u)
                    {
                        _10037 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5085 = ((rw_nfru_diagnostics.Load<uint>(_5060 * 4 + 0) & 64u) != 0u).xxx;
                        _10037 = float3(_5085.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5085.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5085.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10038 = _10037;
                }
                _10069 = _10038;
            }
            else
            {
                float3 _10070;
                if (_4593 == 11u)
                {
                    uint _5098 = (rw_nfru_diagnostics.Load<uint>(_5060 * 4 + 0) >> 8u) & 15u;
                    uint _5101 = (rw_nfru_diagnostics.Load<uint>(_5060 * 4 + 0) >> 12u) & 15u;
                    float3 _10030;
                    if ((_5064 == 2u) || (_5064 == 3u))
                    {
                        _10030 = _3024[_5064];
                    }
                    else
                    {
                        bool _5113 = _5098 == 3u;
                        bool _5115 = _5101 == 3u;
                        float3 _10031;
                        if (_5113 && _5115)
                        {
                            _10031 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10032;
                            if (_5113)
                            {
                                _10032 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10033;
                                if (_5115)
                                {
                                    _10033 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10034;
                                    if ((_5098 == 4u) || (_5101 == 4u))
                                    {
                                        _10034 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10035;
                                        if ((_5098 == 1u) || (_5101 == 1u))
                                        {
                                            _10035 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10292 = (_5064 == 1u).xxx;
                                            _10035 = float3(_10292.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10292.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10292.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10034 = _10035;
                                    }
                                    _10033 = _10034;
                                }
                                _10032 = _10033;
                            }
                            _10031 = _10032;
                        }
                        _10030 = _10031;
                    }
                    _10070 = _10030;
                }
                else
                {
                    _10070 = _3024[min(_5064, 7u)];
                }
                _10069 = _10070;
            }
            _10039 = _10069;
        }
        else
        {
            _10039 = _10040;
        }
        float4 _10073;
        if ((_4593 >= 14u) && (_4593 <= 16u))
        {
            float2 _10071;
            if (_4593 == 14u)
            {
                uint _5171_dummy_parameter;
                uint _5177_dummy_parameter;
                _10071 = r_flow_tm1.Load(int3(clamp(int2(floor(_3687 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5171_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5177_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10072;
                if (_4593 == 16u)
                {
                    uint _8265 = r_warped_flow_qdata_tm1.Load(int3(_3703, 0)).x & 2147483647u;
                    uint _8297 = uint(max((int((_8265 >> 16u) & 15u) - 6), 0));
                    _10072 = ((float2(float((1 - (2 * int((_8265 >> 15u) & 1u))) * int(((_8265 >> uint(7)) & 127u) << _8297)), float((1 - (2 * int((_8265 >> 14u) & 1u))) * int((_8265 & 127u) << _8297))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10072 = _5391 * float2(cbFI_DisplaySize);
                }
                _10071 = _10072;
            }
            uint2 _5210 = uint2(clamp(round(_10071 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5212 = _5210.x;
            uint _5219 = _5210.y;
            _10073 = float4(float(_5212 & 255u), float((_5212 >> 8u) | ((_5219 & 15u) << 4u)), float(_5219 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10074;
            if (_4593 == 17u)
            {
                _10074 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3703, 0)).x != 0u), _4046, 0.0f, 1.0f);
            }
            else
            {
                _10074 = float4(_10039, 1.0f);
            }
            _10073 = _10074;
        }
        rw_output[_3328] = _10073.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5263 = ((uint(_3328.y) * uint(cbFI_DisplaySize.x)) + uint(_3328.x)) * 6u;
            uint _8343 = spvPackHalf2x16(clamp(_6095.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5263 * 4 + 0, (((_8343 & 32767u) >> 4u) | ((((_8343 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6095.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8378 = spvPackHalf2x16(clamp(_6103.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5263 + 1u) * 4 + 0, (((_8378 & 32767u) >> 4u) | ((((_8378 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6103.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8413 = spvPackHalf2x16(clamp(_6111.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5263 + 2u) * 4 + 0, (((_8413 & 32767u) >> 4u) | ((((_8413 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6111.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8448 = spvPackHalf2x16(clamp(_6119.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5263 + 3u) * 4 + 0, (((_8448 & 32767u) >> 4u) | ((((_8448 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6119.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8475 = r_current_interpolation_source.Load(int3(_3328, 0));
            uint _8489 = spvPackHalf2x16(clamp(_8475.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5263 + 4u) * 4 + 0, (((_8489 & 32767u) >> 4u) | ((((_8489 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8475.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10106;
            if (_9952 || (_4593 != 0u))
            {
                _10106 = 4294967295u;
            }
            else
            {
                uint _8524 = spvPackHalf2x16(clamp(_10073.xy, 0.0f.xx, 65000.0f.xx));
                _10106 = (((_8524 & 32767u) >> 4u) | ((((_8524 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10073.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5263 + 5u) * 4 + 0, _10106);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3328] = float4(r_current_interpolation_source.Load(int3(_3328, 0)).xyz, 1.0f).xyz;
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
