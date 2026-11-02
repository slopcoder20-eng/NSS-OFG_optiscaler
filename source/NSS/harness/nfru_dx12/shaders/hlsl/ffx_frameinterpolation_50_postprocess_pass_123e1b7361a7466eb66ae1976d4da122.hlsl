static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3274[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3561 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3561.x >= cbFI_DisplaySize.x, _3561.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3561] = float4(r_present_backbuffer.Load(int3(_3561, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3948 = (float2(_3561) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3959 = int2(floor(_3948 * float2(cbFI_MvDepthLaneSize)));
        int2 _3964 = int2(floor(_3948 * float2(cbFI_FlowLaneSize)));
        float4 _5841 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3948 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5847 = r_warped_filled_flow_tm1.Load(int3(_3964, 0)).xy;
        float2 _5853 = r_warped_filled_motion_tp1.Load(int3(_3959, 0)).xy;
        bool _5875 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9937;
        if (_5875)
        {
            float _5888 = ((2.0f * _3948.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9937 = float2(atan(_5888) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3948.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5888 * _5888))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9937 = _3948;
        }
        bool _3985 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9958;
        bool _9979;
        int2 _9990;
        float3 _11343;
        if (_3985)
        {
            float _9939;
            float _9941;
            _9941 = 2.0f;
            _9939 = -1.0f;
            uint _3623[9];
            float _11775;
            float _11778;
            for (int _9938 = 0; _9938 < 9; _9941 = _11778, _9939 = _11775, _9938++)
            {
                _3623[_9938] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3959 + int2((_9938 % 3) - 1, (_9938 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3623[_9938] != 0u)
                {
                    float _11770;
                    if (_3623[_9938] == 0u)
                    {
                        _11770 = -1.0f;
                    }
                    else
                    {
                        _11770 = float((_3623[_9938] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11778 = min(_9941, _11770);
                    _11775 = max(_9939, _11770);
                }
                else
                {
                    _11778 = _9941;
                    _11775 = _9939;
                }
            }
            float _4031 = float(_9939 >= 0.0f);
            float3 _9738 = 0.0f.xxx;
            _9738.y = _4031;
            float2 _9959;
            bool _9980;
            int2 _9991;
            float3 _11344;
            if ((_9939 - _9941) > 0.0199999995529651641845703125f)
            {
                float _9947;
                int2 _9948;
                float2 _9949;
                int2 _9951;
                float2 _9957;
                _9957 = _5853;
                _9951 = _3959;
                _9949 = _5853;
                _9948 = _3959;
                _9947 = -1.0f;
                float _11783;
                int2 _11787;
                float2 _11798;
                int2 _11809;
                float2 _11842;
                float _11889;
                int _9946 = 0;
                float _11751 = 1000000000.0f;
                for (; _9946 < 9; _11751 = _11889, _9957 = _11842, _9951 = _11809, _9949 = _11798, _9948 = _11787, _9947 = _11783, _9946++)
                {
                    if (_3623[_9946] == 0u)
                    {
                        _11889 = _11751;
                        _11842 = _9957;
                        _11809 = _9951;
                        _11798 = _9949;
                        _11787 = _9948;
                        _11783 = _9947;
                        continue;
                    }
                    int2 _4066 = clamp(_3959 + int2((_9946 % 3) - 1, (_9946 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5963 = _3623[_9946] & 2147483647u;
                    uint _5995 = uint(max((int((_5963 >> 16u) & 15u) - 6), 0));
                    float2 _4072 = (float2(float((1 - (2 * int((_5963 >> 15u) & 1u))) * int(((_5963 >> uint(7)) & 127u) << _5995)), float((1 - (2 * int((_5963 >> 14u) & 1u))) * int((_5963 & 127u) << _5995))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11737;
                    if (_3623[_9946] == 0u)
                    {
                        _11737 = -1.0f;
                    }
                    else
                    {
                        _11737 = float((_3623[_9946] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4077 = _11737 - 0.100000001490116119384765625f;
                    float2 _11738;
                    if (_5875)
                    {
                        float2 _6072 = clamp((((_9937 + (_4072 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6075 = tan(_6072.x);
                        _11738 = (float2(_6075 / cbFI_DeviceToViewDepth.z, (tan(_6072.y) * sqrt(1.0f + (_6075 * _6075))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11738 = _9937 + (_4072 * cbFI_Timestep);
                    }
                    float _4084 = cbFI_Timestep - 1.0f;
                    float2 _11739;
                    if (_5875)
                    {
                        float2 _6143 = clamp((((_9937 + (_4072 * _4084)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6146 = tan(_6143.x);
                        _11739 = (float2(_6146 / cbFI_DeviceToViewDepth.z, (tan(_6143.y) * sqrt(1.0f + (_6146 * _6146))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11739 = _9937 + (_4072 * _4084);
                    }
                    bool _6179 = all(bool2(_11738.x > 0.0f.xx.x, _11738.y > 0.0f.xx.y));
                    bool _6185;
                    if (_6179)
                    {
                        _6185 = all(bool2(_11738.x < 1.0f.xx.x, _11738.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6185 = _6179;
                    }
                    float _11742;
                    if (_6185)
                    {
                        uint _6192_dummy_parameter;
                        _11742 = max((_4077 - (log(((r_depth_tm1.Load(int3(int2(floor(_11738 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6192_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11742 = 0.0f;
                    }
                    bool _6222 = all(bool2(_11739.x > 0.0f.xx.x, _11739.y > 0.0f.xx.y));
                    bool _6228;
                    if (_6222)
                    {
                        _6228 = all(bool2(_11739.x < 1.0f.xx.x, _11739.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6228 = _6222;
                    }
                    float _11743;
                    if (_6228)
                    {
                        uint _6235_dummy_parameter;
                        _11743 = _11742 + max((_4077 - (log(((r_depth_tp1.Load(int3(int2(floor(_11739 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6235_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11743 = _11742;
                    }
                    float _11784;
                    int2 _11788;
                    float2 _11799;
                    int2 _11810;
                    float2 _11843;
                    float _11890;
                    if (_11743 == 0.0f)
                    {
                        bool _4119 = _4077 > _9947;
                        bool2 _11898 = _4119.xx;
                        _11890 = _11751;
                        _11843 = float2(_11898.x ? _4072.x : _9957.x, _11898.y ? _4072.y : _9957.y);
                        _11810 = int2(_11898.x ? _4066.x : _9951.x, _11898.y ? _4066.y : _9951.y);
                        _11799 = _9949;
                        _11788 = _9948;
                        _11784 = _4119 ? _4077 : _9947;
                    }
                    else
                    {
                        bool _4128 = _11743 < _11751;
                        bool2 _11894 = _4128.xx;
                        _11890 = _4128 ? _11743 : _11751;
                        _11843 = _9957;
                        _11810 = _9951;
                        _11799 = float2(_11894.x ? _4072.x : _9949.x, _11894.y ? _4072.y : _9949.y);
                        _11788 = int2(_11894.x ? _4066.x : _9948.x, _11894.y ? _4066.y : _9948.y);
                        _11784 = _9947;
                    }
                    _11889 = _11890;
                    _11842 = _11843;
                    _11809 = _11810;
                    _11798 = _11799;
                    _11787 = _11788;
                    _11783 = _11784;
                }
                bool _4140 = _9947 < 0.0f;
                bool2 _11904 = _4140.xx;
                int2 _11907 = int2(_11904.x ? _9948.x : _9951.x, _11904.y ? _9948.y : _9951.y);
                _11344 = float3(1.0f, _4031, float(any(bool2(_11907.x != _3959.x, _11907.y != _3959.y))));
                _9991 = _11907;
                _9980 = _4140 ? false : true;
                _9959 = float2(_11904.x ? _9949.x : _9957.x, _11904.y ? _9949.y : _9957.y);
            }
            else
            {
                _11344 = _9738;
                _9991 = _3959;
                _9980 = false;
                _9959 = _5853;
            }
            _11343 = _11344;
            _9990 = _9991;
            _9979 = _9980;
            _9958 = _9959;
        }
        else
        {
            _11343 = 0.0f.xxx;
            _9990 = _3959;
            _9979 = false;
            _9958 = _5853;
        }
        float2 _9960;
        if (_5875)
        {
            float2 _6300 = clamp((((_9937 + (_9958 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6303 = tan(_6300.x);
            _9960 = (float2(_6303 / cbFI_DeviceToViewDepth.z, (tan(_6300.y) * sqrt(1.0f + (_6303 * _6303))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9960 = _9937 + (_9958 * cbFI_Timestep);
        }
        float _4163 = cbFI_Timestep - 1.0f;
        float2 _9962;
        if (_5875)
        {
            float2 _6371 = clamp((((_9937 + (_9958 * _4163)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6374 = tan(_6371.x);
            _9962 = (float2(_6374 / cbFI_DeviceToViewDepth.z, (tan(_6371.y) * sqrt(1.0f + (_6374 * _6374))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9962 = _9937 + (_9958 * _4163);
        }
        float _4168 = -cbFI_Timestep;
        float2 _9963;
        if (_5875)
        {
            float2 _6442 = clamp((((_9937 + (_5847 * _4168)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6445 = tan(_6442.x);
            _9963 = (float2(_6445 / cbFI_DeviceToViewDepth.z, (tan(_6442.y) * sqrt(1.0f + (_6445 * _6445))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9963 = _9937 + (_5847 * _4168);
        }
        float _4173 = 1.0f - cbFI_Timestep;
        float2 _9964;
        if (_5875)
        {
            float2 _6513 = clamp((((_9937 + (_5847 * _4173)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6516 = tan(_6513.x);
            _9964 = (float2(_6516 / cbFI_DeviceToViewDepth.z, (tan(_6513.y) * sqrt(1.0f + (_6516 * _6516))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9964 = _9937 + (_5847 * _4173);
        }
        float4 _6551 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9960, 0.0f);
        float3 _6552 = _6551.xyz;
        float4 _6559 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9962, 0.0f);
        float3 _6560 = _6559.xyz;
        float4 _6567 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9963, 0.0f);
        float3 _6568 = _6567.xyz;
        float4 _6575 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9964, 0.0f);
        float3 _6576 = _6575.xyz;
        float4 _6590 = exp(_5841 - max(max(max(_5841.x, _5841.y), _5841.z), _5841.w).xxxx);
        float4 _6597 = _6590 / (dot(_6590, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4192 = _3985 && (!_9979);
        bool _4201;
        if (_4192)
        {
            _4201 = (_6597.z + _6597.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4201 = _4192;
        }
        bool _4212;
        if (_4201)
        {
            _4212 = length((_9963 - _9960) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4212 = _4201;
        }
        bool _10003;
        if (_4212)
        {
            uint4 _6616 = r_warped_motion_qdata_tp1.Load(int3(_9990, 0));
            uint _6617 = _6616.x;
            bool _10006;
            if (_6617 != 0u)
            {
                float _9992;
                if (_6617 == 0u)
                {
                    _9992 = -1.0f;
                }
                else
                {
                    _9992 = float((_6617 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4222 = _9992 - 0.12000000476837158203125f;
                bool _6636 = all(bool2(_9963.x > 0.0f.xx.x, _9963.y > 0.0f.xx.y));
                bool _6642;
                if (_6636)
                {
                    _6642 = all(bool2(_9963.x < 1.0f.xx.x, _9963.y < 1.0f.xx.y));
                }
                else
                {
                    _6642 = _6636;
                }
                bool _4232;
                if (_6642)
                {
                    uint _6649_dummy_parameter;
                    _4232 = (log(((r_depth_tm1.Load(int3(int2(floor(_9963 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6649_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4222;
                }
                else
                {
                    _4232 = _6642;
                }
                bool _4246;
                if (!_4232)
                {
                    bool _6679 = all(bool2(_9964.x > 0.0f.xx.x, _9964.y > 0.0f.xx.y));
                    bool _6685;
                    if (_6679)
                    {
                        _6685 = all(bool2(_9964.x < 1.0f.xx.x, _9964.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6685 = _6679;
                    }
                    bool _4244;
                    if (_6685)
                    {
                        uint _6692_dummy_parameter;
                        _4244 = (log(((r_depth_tp1.Load(int3(int2(floor(_9964 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6692_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4222;
                    }
                    else
                    {
                        _4244 = _6685;
                    }
                    _4246 = _4244;
                }
                else
                {
                    _4246 = _4232;
                }
                _10006 = _4246;
            }
            else
            {
                _10006 = false;
            }
            _10003 = _10006;
        }
        else
        {
            _10003 = false;
        }
        bool _4251 = _9979 || _10003;
        bool _4256;
        if (_4251)
        {
            bool _6722 = all(bool2(_9960.x > 0.0f.xx.x, _9960.y > 0.0f.xx.y));
            bool _6728;
            if (_6722)
            {
                _6728 = all(bool2(_9960.x < 1.0f.xx.x, _9960.y < 1.0f.xx.y));
            }
            else
            {
                _6728 = _6722;
            }
            _4256 = _6728;
        }
        else
        {
            _4256 = _4251;
        }
        bool _4261;
        if (_4256)
        {
            bool _6733 = all(bool2(_9962.x > 0.0f.xx.x, _9962.y > 0.0f.xx.y));
            bool _6739;
            if (_6733)
            {
                _6739 = all(bool2(_9962.x < 1.0f.xx.x, _9962.y < 1.0f.xx.y));
            }
            else
            {
                _6739 = _6733;
            }
            _4261 = _6739;
        }
        else
        {
            _4261 = _4256;
        }
        float4 _10100;
        if (_4261)
        {
            float _4264 = _6597.x;
            float _4266 = _6597.y;
            float _4267 = _4264 + _4266;
            float _4272 = _6597.z + _6597.w;
            float _10021;
            if (_4267 > 0.001000000047497451305389404296875f)
            {
                _10021 = _4264 / _4267;
            }
            else
            {
                _10021 = _4173;
            }
            _10100 = float4(_4264 + (_4272 * _10021), _4266 + (_4272 * (1.0f - _10021)), 0.0f, 0.0f);
        }
        else
        {
            _10100 = _6597;
        }
        bool _6767 = (cbFI_pad0 & 1024u) != 0u;
        bool _6743 = !_6767;
        bool _6744 = !_6743;
        bool _6761;
        if (_6744)
        {
            _6761 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9990.y * cbFI_MvDepthLaneSize.x) + _9990.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6761 = _6743;
        }
        bool _6793;
        if (_6744)
        {
            _6793 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3964.y * cbFI_FlowLaneSize.x) + _3964.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6793 = _6743;
        }
        float _4307 = float(_6793);
        bool _10113;
        float4 _10198;
        float3 _11158;
        if (_6767)
        {
            bool _4317;
            if (_6761)
            {
                _4317 = all(bool2(_9960.x > 0.0f.xx.x, _9960.y > 0.0f.xx.y));
            }
            else
            {
                _4317 = _6761;
            }
            bool _4323;
            if (_4317)
            {
                _4323 = all(bool2(_9960.x < 1.0f.xx.x, _9960.y < 1.0f.xx.y));
            }
            else
            {
                _4323 = _4317;
            }
            bool _4330;
            if (_6761)
            {
                _4330 = all(bool2(_9962.x > 0.0f.xx.x, _9962.y > 0.0f.xx.y));
            }
            else
            {
                _4330 = _6761;
            }
            bool _4336;
            if (_4330)
            {
                _4336 = all(bool2(_9962.x < 1.0f.xx.x, _9962.y < 1.0f.xx.y));
            }
            else
            {
                _4336 = _4330;
            }
            bool _4343;
            if (_6793)
            {
                _4343 = all(bool2(_9963.x > 0.0f.xx.x, _9963.y > 0.0f.xx.y));
            }
            else
            {
                _4343 = _6793;
            }
            bool _4349;
            if (_4343)
            {
                _4349 = all(bool2(_9963.x < 1.0f.xx.x, _9963.y < 1.0f.xx.y));
            }
            else
            {
                _4349 = _4343;
            }
            bool _4356;
            if (_6793)
            {
                _4356 = all(bool2(_9964.x > 0.0f.xx.x, _9964.y > 0.0f.xx.y));
            }
            else
            {
                _4356 = _6793;
            }
            bool _4362;
            if (_4356)
            {
                _4362 = all(bool2(_9964.x < 1.0f.xx.x, _9964.y < 1.0f.xx.y));
            }
            else
            {
                _4362 = _4356;
            }
            bool _4364 = !_6761;
            if (_4364)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6835;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6835);
                }
            }
            bool _4369 = !_6793;
            if (_4369)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6845;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6845);
                }
            }
            if (_6761 && _4369)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6855;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6855);
                }
            }
            if (_4364 && _6793)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6865;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6865);
                }
            }
            float _4388 = float(_4323);
            float _4390 = float(_4336);
            bool _4393 = _4349 && _4362;
            float _10055;
            if (_4393)
            {
                _10055 = 1.0f;
            }
            else
            {
                _10055 = (_4349 || _4362) ? 0.5f : 0.0f;
            }
            bool _10060;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4323)) && (!_4336))
            {
                bool _4423;
                if (_4393)
                {
                    float _10058;
                    do
                    {
                        bool _6949 = all(bool2(_9963.x > 0.0f.xx.x, _9963.y > 0.0f.xx.y));
                        bool _6955;
                        if (_6949)
                        {
                            _6955 = all(bool2(_9963.x < 1.0f.xx.x, _9963.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6955 = _6949;
                        }
                        bool _6886 = !_6955;
                        bool _6893;
                        if (!_6886)
                        {
                            bool _6960 = all(bool2(_9964.x > 0.0f.xx.x, _9964.y > 0.0f.xx.y));
                            bool _6966;
                            if (_6960)
                            {
                                _6966 = all(bool2(_9964.x < 1.0f.xx.x, _9964.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6966 = _6960;
                            }
                            _6893 = !_6966;
                        }
                        else
                        {
                            _6893 = _6886;
                        }
                        if (_6893)
                        {
                            _10058 = 0.0f;
                            break;
                        }
                        uint _6973_dummy_parameter;
                        uint _6989_dummy_parameter;
                        float4 _6914 = mul(float4((float2(_9963.x, 1.0f - _9963.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9963 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6973_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6916 = _6914.w;
                        if (abs(_6916) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10058 = 0.0f;
                            break;
                        }
                        float _6927 = abs(cbFI_DeviceToViewDepth.y / ((_6914.z / _6916) - cbFI_DeviceToViewDepth.x));
                        float _6930 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9964 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6989_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10058 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6927 - _6930) / max(max(_6927, _6930), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4423 = _10058 >= 0.5f;
                }
                else
                {
                    _4423 = _4393;
                }
                bool _4431;
                if (_4423)
                {
                    _4431 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4431 = _4423;
                }
                bool _10061;
                if (_4431)
                {
                    uint _7039_dummy_parameter;
                    float2 _10059;
                    do
                    {
                        float _7065 = 1.0f - _9963.y;
                        float4 _7076 = mul(float4((float2(_9963.x, _7065) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9963 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7039_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7078 = _7076.w;
                        if (!(_7078 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10059 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7091 = ((_7076.xy / _7078.xx) + 1.0f.xx) * 0.5f;
                        _10059 = float2(_7091.x - _9963.x, _7065 - _7091.y);
                        break;
                    } while(false);
                    float2 _4444 = float2(cbFI_DisplaySize);
                    _10061 = length(((_9963 + _10059) - _9964) * _4444) <= ((0.100000001490116119384765625f * length(_10059 * _4444)) + 8.0f);
                }
                else
                {
                    _10061 = _4423;
                }
                _10060 = _10061;
            }
            else
            {
                _10060 = true;
            }
            bool _4458 = !_10060;
            bool _11908 = _4458 ? false : _4362;
            bool _11909 = _4458 ? false : _4349;
            bool _10114;
            float4 _10199;
            if (!(((_4323 && _4336) && _11909) && _11908))
            {
                float4 _4480 = _10100 * float4(_4388, _4390, float(_11909), float(_11908));
                float _4482 = dot(_4480, 1.0f.xxxx);
                bool _4485 = !(_4482 > 0.0f);
                float4 _10200;
                if (!_4485)
                {
                    _10200 = _4480 / _4482.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7113;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7113);
                    }
                    _10200 = 0.0f.xxxx;
                }
                _10199 = _10200;
                _10114 = _4485;
            }
            else
            {
                _10199 = _10100;
                _10114 = false;
            }
            _11158 = float3(_4388, _4390, _10055);
            _10198 = _10199;
            _10113 = _10114;
        }
        else
        {
            _11158 = float3(float(_6761), _4307, 0.0f);
            _10198 = _10100;
            _10113 = false;
        }
        bool _4503 = !_10113;
        float4 _10299;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4503) && _6761)
        {
            float _10195;
            do
            {
                uint4 _7253 = r_warped_motion_qdata_tp1.Load(int3(_9990, 0));
                uint _7254 = _7253.x;
                if (_7254 != 0u)
                {
                    float _10194;
                    if (_7254 == 0u)
                    {
                        _10194 = -1.0f;
                    }
                    else
                    {
                        _10194 = float((_7254 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10195 = _10194;
                    break;
                }
                int _10177;
                uint _10178;
                _10178 = _7254;
                _10177 = -1;
                uint _10193;
                for (; _10177 <= 1; _10178 = _10193, _10177++)
                {
                    _10193 = _10178;
                    for (int _10191 = -1; _10191 <= 1; )
                    {
                        _10193 = max(_10193, r_warped_motion_qdata_tp1.Load(int3(clamp(_9990 + int2(_10191, _10177), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10191++;
                        continue;
                    }
                }
                if (_10178 != 0u)
                {
                    float _10190;
                    if (_10178 == 0u)
                    {
                        _10190 = -1.0f;
                    }
                    else
                    {
                        _10190 = float((_10178 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10195 = _10190;
                    break;
                }
                uint _10180;
                _10180 = 4294967295u;
                uint _11879;
                for (int _10179 = 0; _10179 < 8; _10180 = _11879, _10179++)
                {
                    int _10183 = 0;
                    for (;;)
                    {
                        if (_10183 < 5)
                        {
                            int2 _7204 = _9990 + (_1085[_10179] * _1094[_10183].xx);
                            bool _7207 = any(bool2(_7204.x < int2(0, 0).x, _7204.y < int2(0, 0).y));
                            bool _7215;
                            if (!_7207)
                            {
                                _7215 = any(bool2(_7204.x >= cbFI_MvDepthLaneSize.x, _7204.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7215 = _7207;
                            }
                            if (_7215)
                            {
                                _11879 = _10180;
                                break;
                            }
                            uint4 _7293 = r_warped_motion_qdata_tp1.Load(int3(_7204, 0));
                            uint _7294 = _7293.x;
                            if (_7294 != 0u)
                            {
                                _11879 = min(_10180, _7294);
                                break;
                            }
                            _10183++;
                            continue;
                        }
                        else
                        {
                            _11879 = _10180;
                            break;
                        }
                    }
                }
                float _10182;
                if (_10180 == 4294967295u)
                {
                    _10182 = -1.0f;
                }
                else
                {
                    float _10181;
                    if (_10180 == 0u)
                    {
                        _10181 = -1.0f;
                    }
                    else
                    {
                        _10181 = float((_10180 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10182 = _10181;
                }
                _10195 = _10182;
                break;
            } while(false);
            float _4514 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4518 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4524;
            if (_4518)
            {
                _4524 = _10198.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4524 = _4518;
            }
            bool _4529;
            if (_4524)
            {
                bool _7313 = all(bool2(_9962.x > 0.0f.xx.x, _9962.y > 0.0f.xx.y));
                bool _7319;
                if (_7313)
                {
                    _7319 = all(bool2(_9962.x < 1.0f.xx.x, _9962.y < 1.0f.xx.y));
                }
                else
                {
                    _7319 = _7313;
                }
                _4529 = _7319;
            }
            else
            {
                _4529 = _4524;
            }
            float4 _10241;
            if (_4529)
            {
                float _10216;
                if (_10195 >= 0.0f)
                {
                    _10216 = _10195 - _4514;
                }
                else
                {
                    float _10212;
                    _10212 = 2.0f;
                    float _7376;
                    for (int _10211 = 0; _10211 < 24; _10212 = _7376, _10211++)
                    {
                        float _7340 = float(_10211 & 7) * 0.785398185253143310546875f;
                        int _7342 = _10211 >> 3;
                        int _10213;
                        if (_7342 == 0)
                        {
                            _10213 = 16;
                        }
                        else
                        {
                            _10213 = (_7342 == 1) ? 48 : 96;
                        }
                        uint _7408_dummy_parameter;
                        _7376 = min(_10212, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_9962 + ((cbFI_MvDepthLaneSizeRcp * float(_10213)) * float2(cos(_7340), sin(_7340))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7408_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10216 = _10212;
                }
                uint _7440_dummy_parameter;
                float4 _10242;
                if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_9962 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7440_dummy_parameter))))), 0)).x) > ((exp((_10216 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10242 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10242 = 1.0f.xxxx;
                }
                _10241 = _10242;
            }
            else
            {
                _10241 = 1.0f.xxxx;
            }
            bool _4556 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4562;
            if (_4556)
            {
                _4562 = _10198.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4562 = _4556;
            }
            bool _4567;
            if (_4562)
            {
                bool _7465 = all(bool2(_9960.x > 0.0f.xx.x, _9960.y > 0.0f.xx.y));
                bool _7471;
                if (_7465)
                {
                    _7471 = all(bool2(_9960.x < 1.0f.xx.x, _9960.y < 1.0f.xx.y));
                }
                else
                {
                    _7471 = _7465;
                }
                _4567 = _7471;
            }
            else
            {
                _4567 = _4562;
            }
            float4 _10245;
            if (_4567)
            {
                float _10236;
                if (_10195 >= 0.0f)
                {
                    _10236 = _10195 - _4514;
                }
                else
                {
                    float _10232;
                    _10232 = 2.0f;
                    float _7528;
                    for (int _10231 = 0; _10231 < 24; _10232 = _7528, _10231++)
                    {
                        float _7492 = float(_10231 & 7) * 0.785398185253143310546875f;
                        int _7494 = _10231 >> 3;
                        int _10233;
                        if (_7494 == 0)
                        {
                            _10233 = 16;
                        }
                        else
                        {
                            _10233 = (_7494 == 1) ? 48 : 96;
                        }
                        uint _7544_dummy_parameter;
                        _7528 = min(_10232, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_9960 + ((cbFI_MvDepthLaneSizeRcp * float(_10233)) * float2(cos(_7492), sin(_7492))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7544_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10236 = _10232;
                }
                uint _7592_dummy_parameter;
                float4 _10246;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_9960 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7592_dummy_parameter))))), 0)).x) > ((exp((_10236 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9806 = _10241;
                    _9806.x = 0.0f;
                    _10246 = _9806;
                }
                else
                {
                    _10246 = _10241;
                }
                _10245 = _10246;
            }
            else
            {
                _10245 = _10241;
            }
            float4 _10300;
            if (any(bool4(_10245.x < 1.0f.xxxx.x, _10245.y < 1.0f.xxxx.y, _10245.z < 1.0f.xxxx.z, _10245.w < 1.0f.xxxx.w)))
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7621;
                    rw_nfru_diagnostics.InterlockedAdd(240, 1u, _7621);
                }
                float4 _4598 = _10198 * _10245;
                float _4600 = dot(_4598, 1.0f.xxxx);
                float4 _10301;
                if (_4600 > 0.0f)
                {
                    _10301 = _4598 / _4600.xxxx;
                }
                else
                {
                    bool _4611 = _10245.y == 0.0f;
                    bool _4617;
                    if (_4611)
                    {
                        _4617 = _10245.x > 0.0f;
                    }
                    else
                    {
                        _4617 = _4611;
                    }
                    bool _4622;
                    if (_4617)
                    {
                        bool _7627 = all(bool2(_9960.x > 0.0f.xx.x, _9960.y > 0.0f.xx.y));
                        bool _7633;
                        if (_7627)
                        {
                            _7633 = all(bool2(_9960.x < 1.0f.xx.x, _9960.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7633 = _7627;
                        }
                        _4622 = _7633;
                    }
                    else
                    {
                        _4622 = _4617;
                    }
                    float4 _10302;
                    if (_4622)
                    {
                        _10302 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4627 = _10245.x == 0.0f;
                        bool _4633;
                        if (_4627)
                        {
                            _4633 = _10245.y > 0.0f;
                        }
                        else
                        {
                            _4633 = _4627;
                        }
                        bool _4638;
                        if (_4633)
                        {
                            bool _7638 = all(bool2(_9962.x > 0.0f.xx.x, _9962.y > 0.0f.xx.y));
                            bool _7644;
                            if (_7638)
                            {
                                _7644 = all(bool2(_9962.x < 1.0f.xx.x, _9962.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7644 = _7638;
                            }
                            _4638 = _7644;
                        }
                        else
                        {
                            _4638 = _4633;
                        }
                        bool4 _11910 = _4638.xxxx;
                        _10302 = float4(_11910.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10198.x, _11910.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10198.y, _11910.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10198.z, _11910.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10198.w);
                    }
                    _10301 = _10302;
                }
                _10300 = _10301;
            }
            else
            {
                _10300 = _10198;
            }
            _10299 = _10300;
        }
        else
        {
            _10299 = _10198;
        }
        float4 _10845;
        bool _10865;
        float3 _10979;
        if (((cbFI_pad0 & 32768u) != 0u) && _4503)
        {
            bool _4655 = _10299.x > 0.00999999977648258209228515625f;
            bool _4658 = _10299.y > 0.00999999977648258209228515625f;
            bool _4667 = (_10299.z + _10299.w) > 0.0199999995529651641845703125f;
            bool _4673;
            if (_4667)
            {
                bool _7649 = all(bool2(_9963.x > 0.0f.xx.x, _9963.y > 0.0f.xx.y));
                bool _7655;
                if (_7649)
                {
                    _7655 = all(bool2(_9963.x < 1.0f.xx.x, _9963.y < 1.0f.xx.y));
                }
                else
                {
                    _7655 = _7649;
                }
                _4673 = _7655;
            }
            else
            {
                _4673 = _4667;
            }
            bool _4678;
            if (_4673)
            {
                bool _7660 = all(bool2(_9964.x > 0.0f.xx.x, _9964.y > 0.0f.xx.y));
                bool _7666;
                if (_7660)
                {
                    _7666 = all(bool2(_9964.x < 1.0f.xx.x, _9964.y < 1.0f.xx.y));
                }
                else
                {
                    _7666 = _7660;
                }
                _4678 = _7666;
            }
            else
            {
                _4678 = _4673;
            }
            bool _4685;
            if (_4678)
            {
                float _10310;
                do
                {
                    bool _7749 = all(bool2(_9963.x > 0.0f.xx.x, _9963.y > 0.0f.xx.y));
                    bool _7755;
                    if (_7749)
                    {
                        _7755 = all(bool2(_9963.x < 1.0f.xx.x, _9963.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7755 = _7749;
                    }
                    bool _7686 = !_7755;
                    bool _7693;
                    if (!_7686)
                    {
                        bool _7760 = all(bool2(_9964.x > 0.0f.xx.x, _9964.y > 0.0f.xx.y));
                        bool _7766;
                        if (_7760)
                        {
                            _7766 = all(bool2(_9964.x < 1.0f.xx.x, _9964.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7766 = _7760;
                        }
                        _7693 = !_7766;
                    }
                    else
                    {
                        _7693 = _7686;
                    }
                    if (_7693)
                    {
                        _10310 = 0.0f;
                        break;
                    }
                    uint _7773_dummy_parameter;
                    uint _7789_dummy_parameter;
                    float4 _7714 = mul(float4((float2(_9963.x, 1.0f - _9963.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9963 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7773_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7716 = _7714.w;
                    if (abs(_7716) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10310 = 0.0f;
                        break;
                    }
                    float _7727 = abs(cbFI_DeviceToViewDepth.y / ((_7714.z / _7716) - cbFI_DeviceToViewDepth.x));
                    float _7730 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9964 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7789_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10310 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7727 - _7730) / max(max(_7727, _7730), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4685 = _10310 < 0.5f;
            }
            else
            {
                _4685 = _4678;
            }
            float4 _10325;
            if (_4685)
            {
                uint _7839_dummy_parameter;
                uint _7870_dummy_parameter;
                float4 _10326;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9963 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7839_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9964 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7870_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10326 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10326 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10325 = _10326;
            }
            else
            {
                _10325 = 1.0f.xxxx;
            }
            bool _4709;
            if (_6761)
            {
                bool _7899 = all(bool2(_9960.x > 0.0f.xx.x, _9960.y > 0.0f.xx.y));
                bool _7905;
                if (_7899)
                {
                    _7905 = all(bool2(_9960.x < 1.0f.xx.x, _9960.y < 1.0f.xx.y));
                }
                else
                {
                    _7905 = _7899;
                }
                _4709 = _7905;
            }
            else
            {
                _4709 = _6761;
            }
            bool _4715;
            if (_6761)
            {
                bool _7910 = all(bool2(_9962.x > 0.0f.xx.x, _9962.y > 0.0f.xx.y));
                bool _7916;
                if (_7910)
                {
                    _7916 = all(bool2(_9962.x < 1.0f.xx.x, _9962.y < 1.0f.xx.y));
                }
                else
                {
                    _7916 = _7910;
                }
                _4715 = _7916;
            }
            else
            {
                _4715 = _6761;
            }
            bool _4721;
            if (_6793)
            {
                bool _7921 = all(bool2(_9963.x > 0.0f.xx.x, _9963.y > 0.0f.xx.y));
                bool _7927;
                if (_7921)
                {
                    _7927 = all(bool2(_9963.x < 1.0f.xx.x, _9963.y < 1.0f.xx.y));
                }
                else
                {
                    _7927 = _7921;
                }
                _4721 = _7927;
            }
            else
            {
                _4721 = _6793;
            }
            bool _4727;
            if (_6793)
            {
                bool _7932 = all(bool2(_9964.x > 0.0f.xx.x, _9964.y > 0.0f.xx.y));
                bool _7938;
                if (_7932)
                {
                    _7938 = all(bool2(_9964.x < 1.0f.xx.x, _9964.y < 1.0f.xx.y));
                }
                else
                {
                    _7938 = _7932;
                }
                _4727 = _7938;
            }
            else
            {
                _4727 = _6793;
            }
            bool _4730 = _4721 != _4727;
            bool _4736;
            if (_4730)
            {
                _4736 = _4709 || _4715;
            }
            else
            {
                _4736 = _4730;
            }
            float4 _10414;
            if (_4736)
            {
                float4 _9833 = _10325;
                _9833.z = 0.0f;
                _9833.w = 0.0f;
                _10414 = _9833;
            }
            else
            {
                _10414 = _10325;
            }
            bool _4743 = _4709 && _4655;
            bool _4746 = _4715 && _4658;
            float4 _10519;
            float3 _11057;
            if (_4743 || _4746)
            {
                float _10409;
                do
                {
                    uint4 _8077 = r_warped_motion_qdata_tp1.Load(int3(_9990, 0));
                    uint _8078 = _8077.x;
                    if (_8078 != 0u)
                    {
                        float _10408;
                        if (_8078 == 0u)
                        {
                            _10408 = -1.0f;
                        }
                        else
                        {
                            _10408 = float((_8078 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10409 = _10408;
                        break;
                    }
                    int _10391;
                    uint _10392;
                    _10392 = _8078;
                    _10391 = -1;
                    uint _10407;
                    for (; _10391 <= 1; _10392 = _10407, _10391++)
                    {
                        _10407 = _10392;
                        for (int _10405 = -1; _10405 <= 1; )
                        {
                            _10407 = max(_10407, r_warped_motion_qdata_tp1.Load(int3(clamp(_9990 + int2(_10405, _10391), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10405++;
                            continue;
                        }
                    }
                    if (_10392 != 0u)
                    {
                        float _10404;
                        if (_10392 == 0u)
                        {
                            _10404 = -1.0f;
                        }
                        else
                        {
                            _10404 = float((_10392 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10409 = _10404;
                        break;
                    }
                    uint _10394;
                    _10394 = 4294967295u;
                    uint _11880;
                    for (int _10393 = 0; _10393 < 8; _10394 = _11880, _10393++)
                    {
                        int _10397 = 0;
                        for (;;)
                        {
                            if (_10397 < 5)
                            {
                                int2 _8028 = _9990 + (_1085[_10393] * _1094[_10397].xx);
                                bool _8031 = any(bool2(_8028.x < int2(0, 0).x, _8028.y < int2(0, 0).y));
                                bool _8039;
                                if (!_8031)
                                {
                                    _8039 = any(bool2(_8028.x >= cbFI_MvDepthLaneSize.x, _8028.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8039 = _8031;
                                }
                                if (_8039)
                                {
                                    _11880 = _10394;
                                    break;
                                }
                                uint4 _8117 = r_warped_motion_qdata_tp1.Load(int3(_8028, 0));
                                uint _8118 = _8117.x;
                                if (_8118 != 0u)
                                {
                                    _11880 = min(_10394, _8118);
                                    break;
                                }
                                _10397++;
                                continue;
                            }
                            else
                            {
                                _11880 = _10394;
                                break;
                            }
                        }
                    }
                    float _10396;
                    if (_10394 == 4294967295u)
                    {
                        _10396 = -1.0f;
                    }
                    else
                    {
                        float _10395;
                        if (_10394 == 0u)
                        {
                            _10395 = -1.0f;
                        }
                        else
                        {
                            _10395 = float((_10394 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10396 = _10395;
                    }
                    _10409 = _10396;
                    break;
                } while(false);
                bool _4754 = _10409 < 0.0f;
                float _10410;
                if (_4754)
                {
                    _10410 = 0.0f;
                }
                else
                {
                    _10410 = _10409 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8139_dummy_parameter;
                uint _8171_dummy_parameter;
                float4 _10447;
                if ((_4754 && _4743) && _4746)
                {
                    uint _8203_dummy_parameter;
                    float _8227 = log(((r_depth_tm1.Load(int3(int2(floor(_9960 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8203_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8235_dummy_parameter;
                    float _8259 = log(((r_depth_tp1.Load(int3(int2(floor(_9962 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8235_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10448;
                    if (_8227 > (_8259 + 0.07999999821186065673828125f))
                    {
                        float4 _9837 = _10414;
                        _9837.x = 0.0f;
                        _10448 = _9837;
                    }
                    else
                    {
                        float4 _10449;
                        if (_8259 > (_8227 + 0.07999999821186065673828125f))
                        {
                            float4 _9839 = _10414;
                            _9839.y = 0.0f;
                            _10449 = _9839;
                        }
                        else
                        {
                            _10449 = _10414;
                        }
                        _10448 = _10449;
                    }
                    _10447 = _10448;
                }
                else
                {
                    _10447 = _10414;
                }
                float _4806 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4808 = _10409 >= 0.0f;
                float _10430;
                if (_4808)
                {
                    _10430 = _10409 - _4806;
                }
                else
                {
                    float _10426;
                    if (_4743)
                    {
                        float _10425;
                        _10425 = 2.0f;
                        float _8317;
                        for (int _10424 = 0; _10424 < 24; _10425 = _8317, _10424++)
                        {
                            float _8281 = float(_10424 & 7) * 0.785398185253143310546875f;
                            int _8283 = _10424 >> 3;
                            int _10427;
                            if (_8283 == 0)
                            {
                                _10427 = 16;
                            }
                            else
                            {
                                _10427 = (_8283 == 1) ? 48 : 96;
                            }
                            uint _8333_dummy_parameter;
                            _8317 = min(_10425, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_9960 + ((cbFI_MvDepthLaneSizeRcp * float(_10427)) * float2(cos(_8281), sin(_8281))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8333_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10426 = _10425;
                    }
                    else
                    {
                        _10426 = 0.0f;
                    }
                    _10430 = _10426;
                }
                float _10437;
                if (_4808)
                {
                    _10437 = _10409 - _4806;
                }
                else
                {
                    float _10433;
                    if (_4746)
                    {
                        float _10432;
                        _10432 = 2.0f;
                        float _8431;
                        for (int _10431 = 0; _10431 < 24; _10432 = _8431, _10431++)
                        {
                            float _8395 = float(_10431 & 7) * 0.785398185253143310546875f;
                            int _8397 = _10431 >> 3;
                            int _10434;
                            if (_8397 == 0)
                            {
                                _10434 = 16;
                            }
                            else
                            {
                                _10434 = (_8397 == 1) ? 48 : 96;
                            }
                            uint _8463_dummy_parameter;
                            _8431 = min(_10432, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_9962 + ((cbFI_MvDepthLaneSizeRcp * float(_10434)) * float2(cos(_8395), sin(_8395))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8463_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10433 = _10432;
                    }
                    else
                    {
                        _10433 = 0.0f;
                    }
                    _10437 = _10433;
                }
                float _10438;
                if (_4743)
                {
                    uint _8495_dummy_parameter;
                    _10438 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_9960 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8495_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10438 = 0.0f;
                }
                float _10439;
                if (_4746)
                {
                    uint _8515_dummy_parameter;
                    _10439 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_9962 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8515_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10439 = 0.0f;
                }
                bool _4863;
                if (_4743)
                {
                    _4863 = _10438 > ((exp((_10430 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4863 = _4743;
                }
                float4 _10455;
                if (_4863)
                {
                    float4 _9841 = _10447;
                    _9841.x = 0.0f;
                    _10455 = _9841;
                }
                else
                {
                    _10455 = _10447;
                }
                bool _4875;
                if (_4746)
                {
                    _4875 = _10439 > ((exp((_10437 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4875 = _4746;
                }
                float4 _10457;
                if (_4875)
                {
                    float4 _9843 = _10455;
                    _9843.y = 0.0f;
                    _10457 = _9843;
                }
                else
                {
                    _10457 = _10455;
                }
                float4 _10520;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4808)
                {
                    bool _4895;
                    if (_4743)
                    {
                        _4895 = _10438 < ((exp((_10430 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4895 = _4743;
                    }
                    float4 _10459;
                    if (_4895)
                    {
                        float4 _9845 = _10457;
                        _9845.x = 0.0f;
                        _10459 = _9845;
                    }
                    else
                    {
                        _10459 = _10457;
                    }
                    bool _4907;
                    if (_4746)
                    {
                        _4907 = _10439 < ((exp((_10437 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4907 = _4746;
                    }
                    float4 _10521;
                    if (_4907)
                    {
                        float4 _9847 = _10459;
                        _9847.y = 0.0f;
                        _10521 = _9847;
                    }
                    else
                    {
                        _10521 = _10459;
                    }
                    _10520 = _10521;
                }
                else
                {
                    _10520 = _10457;
                }
                _11057 = float3(_10410, log(((r_depth_tm1.Load(int3(int2(floor(_9960 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8139_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_9962 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8171_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _10519 = _10520;
            }
            else
            {
                _11057 = float3(0.0f, 0.0f, 0.5f);
                _10519 = _10414;
            }
            bool _4918 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4667;
            bool _4924;
            if (_4918)
            {
                _4924 = _4721 || _4727;
            }
            else
            {
                _4924 = _4918;
            }
            float4 _10542;
            if (_4924)
            {
                float _10514;
                do
                {
                    uint4 _8695 = r_warped_motion_qdata_tp1.Load(int3(_9990, 0));
                    uint _8696 = _8695.x;
                    if (_8696 != 0u)
                    {
                        float _10513;
                        if (_8696 == 0u)
                        {
                            _10513 = -1.0f;
                        }
                        else
                        {
                            _10513 = float((_8696 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10514 = _10513;
                        break;
                    }
                    int _10496;
                    uint _10497;
                    _10497 = _8696;
                    _10496 = -1;
                    uint _10512;
                    for (; _10496 <= 1; _10497 = _10512, _10496++)
                    {
                        _10512 = _10497;
                        for (int _10510 = -1; _10510 <= 1; )
                        {
                            _10512 = max(_10512, r_warped_motion_qdata_tp1.Load(int3(clamp(_9990 + int2(_10510, _10496), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10510++;
                            continue;
                        }
                    }
                    if (_10497 != 0u)
                    {
                        float _10509;
                        if (_10497 == 0u)
                        {
                            _10509 = -1.0f;
                        }
                        else
                        {
                            _10509 = float((_10497 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10514 = _10509;
                        break;
                    }
                    uint _10499;
                    _10499 = 4294967295u;
                    uint _11881;
                    for (int _10498 = 0; _10498 < 8; _10499 = _11881, _10498++)
                    {
                        int _10502 = 0;
                        for (;;)
                        {
                            if (_10502 < 5)
                            {
                                int2 _8646 = _9990 + (_1085[_10498] * _1094[_10502].xx);
                                bool _8649 = any(bool2(_8646.x < int2(0, 0).x, _8646.y < int2(0, 0).y));
                                bool _8657;
                                if (!_8649)
                                {
                                    _8657 = any(bool2(_8646.x >= cbFI_MvDepthLaneSize.x, _8646.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8657 = _8649;
                                }
                                if (_8657)
                                {
                                    _11881 = _10499;
                                    break;
                                }
                                uint4 _8735 = r_warped_motion_qdata_tp1.Load(int3(_8646, 0));
                                uint _8736 = _8735.x;
                                if (_8736 != 0u)
                                {
                                    _11881 = min(_10499, _8736);
                                    break;
                                }
                                _10502++;
                                continue;
                            }
                            else
                            {
                                _11881 = _10499;
                                break;
                            }
                        }
                    }
                    float _10501;
                    if (_10499 == 4294967295u)
                    {
                        _10501 = -1.0f;
                    }
                    else
                    {
                        float _10500;
                        if (_10499 == 0u)
                        {
                            _10500 = -1.0f;
                        }
                        else
                        {
                            _10500 = float((_10499 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10501 = _10500;
                    }
                    _10514 = _10501;
                    break;
                } while(false);
                float4 _10543;
                if (_10514 >= 0.0f)
                {
                    float _8757 = (exp((_10514 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4943;
                    if (_4721)
                    {
                        uint _8764_dummy_parameter;
                        _4943 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_9963 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8764_dummy_parameter))))), 0)).x) > _8757;
                    }
                    else
                    {
                        _4943 = _4721;
                    }
                    float4 _10532;
                    if (_4943)
                    {
                        float4 _9849 = _10519;
                        _9849.z = 0.0f;
                        _10532 = _9849;
                    }
                    else
                    {
                        _10532 = _10519;
                    }
                    bool _4955;
                    if (_4727)
                    {
                        uint _8784_dummy_parameter;
                        _4955 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_9964 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8784_dummy_parameter))))), 0)).x) > _8757;
                    }
                    else
                    {
                        _4955 = _4727;
                    }
                    float4 _10544;
                    if (_4955)
                    {
                        float4 _9851 = _10532;
                        _9851.w = 0.0f;
                        _10544 = _9851;
                    }
                    else
                    {
                        _10544 = _10532;
                    }
                    _10543 = _10544;
                }
                else
                {
                    _10543 = _10519;
                }
                _10542 = _10543;
            }
            else
            {
                _10542 = _10519;
            }
            bool _4963 = _4709 != _4715;
            bool _4970;
            if (_4963)
            {
                _4970 = _4709 ? _4655 : _4658;
            }
            else
            {
                _4970 = _4963;
            }
            bool _4977;
            if (_4970)
            {
                _4977 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _4977 = _4970;
            }
            float4 _10627;
            if (_4977)
            {
                bool2 _4982 = _4709.xx;
                float2 _4983 = float2(_4982.x ? _9960.x : _9962.x, _4982.y ? _9960.y : _9962.y);
                float _10534;
                if (_4709)
                {
                    uint _8804_dummy_parameter;
                    _10534 = r_depth_tm1.Load(int3(int2(floor(_4983 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8804_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8820_dummy_parameter;
                    _10534 = r_depth_tp1.Load(int3(int2(floor(_4983 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8820_dummy_parameter))))), 0)).x;
                }
                float4x4 _10535;
                if (_4709)
                {
                    _10535 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10535 = cbFI_MotionTP1ToTM1;
                }
                float2 _10536;
                do
                {
                    float _8847 = _4983.x;
                    float _8850 = 1.0f - _4983.y;
                    float4 _8861 = mul(float4((float2(_8847, _8850) * 2.0f) - 1.0f.xx, _10534, 1.0f), _10535);
                    float _8863 = _8861.w;
                    if (!(_8863 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10536 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8876 = ((_8861.xy / _8863.xx) + 1.0f.xx) * 0.5f;
                    _10536 = float2(_8876.x - _8847, _8850 - _8876.y);
                    break;
                } while(false);
                float2 _5013 = float2(cbFI_DisplaySize);
                float4 _10628;
                if (!(length(((_4983 + _10536) - float2(_4982.x ? _9962.x : _9960.x, _4982.y ? _9962.y : _9960.y)) * _5013) <= ((0.100000001490116119384765625f * length(_10536 * _5013)) + 8.0f)))
                {
                    float4 _10629;
                    if (_4709)
                    {
                        float4 _9861 = _10542;
                        _9861.x = 0.0f;
                        _10629 = _9861;
                    }
                    else
                    {
                        float4 _9863 = _10542;
                        _9863.y = 0.0f;
                        _10629 = _9863;
                    }
                    _10628 = _10629;
                }
                else
                {
                    _10628 = _10542;
                }
                _10627 = _10628;
            }
            else
            {
                _10627 = _10542;
            }
            float4 _5038 = _10299 * _10627;
            float _5040 = dot(_5038, 1.0f.xxxx);
            float4 _10846;
            bool _10866;
            if (_5040 > 0.0f)
            {
                _10866 = _10113;
                _10846 = _5038 / _5040.xxxx;
            }
            else
            {
                bool _5051 = any(bool4(_10627.x < 1.0f.xxxx.x, _10627.y < 1.0f.xxxx.y, _10627.z < 1.0f.xxxx.z, _10627.w < 1.0f.xxxx.w));
                if (_5051)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8898;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8898);
                    }
                }
                bool4 _11913 = _5051.xxxx;
                _10866 = _5051 ? true : _10113;
                _10846 = float4(_11913.x ? 0.0f.xxxx.x : _10299.x, _11913.y ? 0.0f.xxxx.y : _10299.y, _11913.z ? 0.0f.xxxx.z : _10299.z, _11913.w ? 0.0f.xxxx.w : _10299.w);
            }
            _10979 = _11057;
            _10865 = _10866;
            _10845 = _10846;
        }
        else
        {
            _10979 = float3(0.0f, 0.0f, 0.5f);
            _10865 = _10113;
            _10845 = _10299;
        }
        uint _5060 = (cbFI_pad0 >> 24u) & 31u;
        uint _5064 = (cbFI_pad0 >> 16u) & 255u;
        bool _5066 = _5060 != 0u;
        bool _5068 = _5064 == 12u;
        bool _5071 = _5064 == 13u;
        float4 _10862;
        if ((_5066 || _5068) || _5071)
        {
            float _10630;
            do
            {
                bool _8982 = all(bool2(_9963.x > 0.0f.xx.x, _9963.y > 0.0f.xx.y));
                bool _8988;
                if (_8982)
                {
                    _8988 = all(bool2(_9963.x < 1.0f.xx.x, _9963.y < 1.0f.xx.y));
                }
                else
                {
                    _8988 = _8982;
                }
                bool _8919 = !_8988;
                bool _8926;
                if (!_8919)
                {
                    bool _8993 = all(bool2(_9964.x > 0.0f.xx.x, _9964.y > 0.0f.xx.y));
                    bool _8999;
                    if (_8993)
                    {
                        _8999 = all(bool2(_9964.x < 1.0f.xx.x, _9964.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8999 = _8993;
                    }
                    _8926 = !_8999;
                }
                else
                {
                    _8926 = _8919;
                }
                if (_8926)
                {
                    _10630 = 0.0f;
                    break;
                }
                uint _9006_dummy_parameter;
                uint _9022_dummy_parameter;
                float4 _8947 = mul(float4((float2(_9963.x, 1.0f - _9963.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9963 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9006_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8949 = _8947.w;
                if (abs(_8949) < 9.9999999747524270787835121154785e-07f)
                {
                    _10630 = 0.0f;
                    break;
                }
                float _8960 = abs(cbFI_DeviceToViewDepth.y / ((_8947.z / _8949) - cbFI_DeviceToViewDepth.x));
                float _8963 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9964 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9022_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10630 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8960 - _8963) / max(max(_8960, _8963), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9070 = all(bool2(_9964.x > 0.0f.xx.x, _9964.y > 0.0f.xx.y));
            bool _9076;
            if (_9070)
            {
                _9076 = all(bool2(_9964.x < 1.0f.xx.x, _9964.y < 1.0f.xx.y));
            }
            else
            {
                _9076 = _9070;
            }
            float _10631;
            if (_9076)
            {
                uint _9083_dummy_parameter;
                _10631 = length((_5847 + (r_motion_tp1.Load(int3(int2(floor(_9964 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9083_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10631 = 1000000.0f;
            }
            float _10642;
            if ((_5060 & 1u) != 0u)
            {
                _10642 = _10630;
            }
            else
            {
                _10642 = 1.0f;
            }
            float _10643;
            if ((_5060 & 2u) != 0u)
            {
                _10643 = _10642 * (1.0f - smoothstep(2.0f, 8.0f, _10631));
            }
            else
            {
                _10643 = _10642;
            }
            float _10644;
            if ((_5060 & 4u) != 0u)
            {
                _10644 = _10643 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6568 - _6576) - length(_6552 - _6560))));
            }
            else
            {
                _10644 = _10643;
            }
            float _10856;
            if ((_5060 & 8u) != 0u)
            {
                _10856 = lerp(1.0f, _10644, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6552 - _6560)));
            }
            else
            {
                _10856 = _10644;
            }
            bool _5146 = (_5060 & 16u) != 0u;
            bool _5155;
            if (_5146)
            {
                _5155 = length(_9958 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5155 = _5146;
            }
            float _11915 = _5155 ? 1.0f : _10856;
            bool _5161 = _5066 && _6761;
            bool _5166;
            if (_5161)
            {
                bool _9108 = all(bool2(_9960.x > 0.0f.xx.x, _9960.y > 0.0f.xx.y));
                bool _9114;
                if (_9108)
                {
                    _9114 = all(bool2(_9960.x < 1.0f.xx.x, _9960.y < 1.0f.xx.y));
                }
                else
                {
                    _9114 = _9108;
                }
                _5166 = _9114;
            }
            else
            {
                _5166 = _5161;
            }
            bool _5171;
            if (_5166)
            {
                bool _9119 = all(bool2(_9962.x > 0.0f.xx.x, _9962.y > 0.0f.xx.y));
                bool _9125;
                if (_9119)
                {
                    _9125 = all(bool2(_9962.x < 1.0f.xx.x, _9962.y < 1.0f.xx.y));
                }
                else
                {
                    _9125 = _9119;
                }
                _5171 = _9125;
            }
            else
            {
                _5171 = _5166;
            }
            float4 _10863;
            if (_5171)
            {
                float _5177 = _10845.x + _10845.y;
                float _5186 = (_10845.z + _10845.w) * (1.0f - _11915);
                float _10859;
                if (_5177 > 9.9999997473787516355514526367188e-06f)
                {
                    _10859 = _10845.x / _5177;
                }
                else
                {
                    _10859 = _4173;
                }
                _10863 = float4(_10845.x + (_5186 * _10859), _10845.y + (_5186 * (1.0f - _10859)), _10845.zw * _11915);
            }
            else
            {
                _10863 = _10845;
            }
            _10862 = _10863;
        }
        else
        {
            _10862 = _10845;
        }
        float3 _11683;
        if (_10865)
        {
            float3 _9131 = r_current_interpolation_source.Load(int3(_3561, 0)).xyz;
            float3 _11684;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6761)
            {
                uint _9138_dummy_parameter;
                float _10970;
                _10970 = r_depth_tm1.Load(int3(int2(floor(_9960 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9138_dummy_parameter))))), 0)).x;
                float _5298;
                for (int _10969 = 0; _10969 < 24; _10970 = _5298, _10969++)
                {
                    float _5270 = float(_10969 & 7) * 0.785398185253143310546875f;
                    int _5272 = _10969 >> 3;
                    int _11734;
                    if (_5272 == 0)
                    {
                        _11734 = 16;
                    }
                    else
                    {
                        _11734 = (_5272 == 1) ? 48 : 96;
                    }
                    uint _9158_dummy_parameter;
                    _5298 = max(_10970, r_depth_tm1.Load(int3(int2(floor(clamp(_9960 + ((cbFI_MvDepthLaneSizeRcp * float(_11734)) * float2(cos(_5270), sin(_5270))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9158_dummy_parameter))))), 0)).x);
                }
                float2 _10971;
                do
                {
                    float _9180 = 1.0f - _9960.y;
                    float4 _9191 = mul(float4((float2(_9960.x, _9180) * 2.0f) - 1.0f.xx, _10970, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9193 = _9191.w;
                    if (!(_9193 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10971 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9206 = ((_9191.xy / _9193.xx) + 1.0f.xx) * 0.5f;
                    _10971 = float2(_9206.x - _9960.x, _9180 - _9206.y);
                    break;
                } while(false);
                float2 _5309 = _9960 + _10971;
                bool _9224 = all(bool2(_5309.x > 0.0f.xx.x, _5309.y > 0.0f.xx.y));
                bool _9230;
                if (_9224)
                {
                    _9230 = all(bool2(_5309.x < 1.0f.xx.x, _5309.y < 1.0f.xx.y));
                }
                else
                {
                    _9230 = _9224;
                }
                float3 _11685;
                if (_9230)
                {
                    float _5315 = abs(cbFI_DeviceToViewDepth.y / (_10970 - cbFI_DeviceToViewDepth.x));
                    uint _9250_dummy_parameter;
                    int2 _9250 = int2(spvTextureSize(r_depth_m2, uint(0), _9250_dummy_parameter));
                    float _5319 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5309 * float2(_9250))), int2(0, 0), _9250 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11690;
                    if (abs(_5319 - _5315) <= (0.20000000298023223876953125f * max(_5319, _5315)))
                    {
                        uint _9284_dummy_parameter;
                        int2 _9284 = int2(spvTextureSize(r_colour_m2, uint(0), _9284_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9307;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9307);
                        }
                        _11690 = r_colour_m2.Load(int3(clamp(int2(floor(_5309 * float2(_9284))), int2(0, 0), _9284 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9317;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9317);
                        }
                        _11690 = _9131;
                    }
                    _11685 = _11690;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9327;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9327);
                    }
                    _11685 = _9131;
                }
                _11684 = _11685;
            }
            else
            {
                _11684 = _9131;
            }
            _11683 = _11684;
        }
        else
        {
            _11683 = (((_6552 * _10862.x) + (_6560 * _10862.y)) + (_6568 * _10862.z)) + (_6576 * _10862.w);
        }
        uint _5347 = cbFI_pad0 & 255u;
        bool _11575;
        float3 _11682;
        if (_5347 != 0u)
        {
            float3 _5352 = r_present_backbuffer.Load(int3(_3561, 0)).xyz;
            float3 _5356 = r_current_interpolation_source.Load(int3(_3561, 0)).xyz;
            float3 _5360 = abs(_5352 - _5356);
            float3 _10974;
            if (_5347 == 2u)
            {
                _10974 = (abs(_5356) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _10974 = 0.000244140625f.xxx;
            }
            bool _5376 = any(bool3(_5360.x > _10974.x, _5360.y > _10974.y, _5360.z > _10974.z));
            bool3 _11916 = _5376.xxx;
            _11682 = float3(_11916.x ? _5352.x : _11683.x, _11916.y ? _5352.y : _11683.y, _11916.z ? _5352.z : _11683.z);
            _11575 = _5376;
        }
        else
        {
            _11682 = _11683;
            _11575 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9342;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9342);
        }
        float3 _11665;
        if (_5064 == 1u)
        {
            _11665 = lerp(_6552, _6560, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11666;
            if (_5064 == 2u)
            {
                _11666 = lerp(_6568, _6576, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11667;
                if (_5064 == 3u)
                {
                    _11667 = float(_11575).xxx;
                }
                else
                {
                    float3 _11668;
                    if (_5064 == 4u)
                    {
                        _11668 = float3(((_9958 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11669;
                        if (_5064 == 5u)
                        {
                            _11669 = float3(((_5847 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11670;
                            if (_5064 == 6u)
                            {
                                _11670 = float3(_10862.xy, _10862.z + _10862.w);
                            }
                            else
                            {
                                float3 _11671;
                                if (_5064 == 7u)
                                {
                                    _11671 = r_current_interpolation_source.Load(int3(_3561, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11672;
                                    if (_5064 == 8u)
                                    {
                                        _11672 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3948, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11673;
                                        if (_5068)
                                        {
                                            uint _9364_dummy_parameter;
                                            uint _9396_dummy_parameter;
                                            _11673 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3948 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9364_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3948 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9396_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11674;
                                            if (_5071)
                                            {
                                                _11674 = _6568;
                                            }
                                            else
                                            {
                                                float3 _11675;
                                                if (_5064 == 20u)
                                                {
                                                    _11675 = _6552;
                                                }
                                                else
                                                {
                                                    float3 _11676;
                                                    if (_5064 == 21u)
                                                    {
                                                        _11676 = _6560;
                                                    }
                                                    else
                                                    {
                                                        float3 _11677;
                                                        if (_5064 == 22u)
                                                        {
                                                            _11677 = _6576;
                                                        }
                                                        else
                                                        {
                                                            float3 _11678;
                                                            if (_5064 == 18u)
                                                            {
                                                                _11678 = _11343;
                                                            }
                                                            else
                                                            {
                                                                float3 _11679;
                                                                if (_5064 == 19u)
                                                                {
                                                                    _11679 = _11158;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _11918 = (_5064 == 23u).xxx;
                                                                    _11679 = float3(_11918.x ? _10979.x : _11682.x, _11918.y ? _10979.y : _11682.y, _11918.z ? _10979.z : _11682.z);
                                                                }
                                                                _11678 = _11679;
                                                            }
                                                            _11677 = _11678;
                                                        }
                                                        _11676 = _11677;
                                                    }
                                                    _11675 = _11676;
                                                }
                                                _11674 = _11675;
                                            }
                                            _11673 = _11674;
                                        }
                                        _11672 = _11673;
                                    }
                                    _11671 = _11672;
                                }
                                _11670 = _11671;
                            }
                            _11669 = _11670;
                        }
                        _11668 = _11669;
                    }
                    _11667 = _11668;
                }
                _11666 = _11667;
            }
            _11665 = _11666;
        }
        float3 _11664;
        if ((_5064 >= 9u) && (_5064 <= 11u))
        {
            uint _5540 = 64u + uint((_9990.y * cbFI_MvDepthLaneSize.x) + _9990.x);
            uint _5544 = rw_nfru_diagnostics.Load<uint>(_5540 * 4 + 0) & 15u;
            float3 _11695;
            if (_5064 == 10u)
            {
                float3 _11663;
                if ((rw_nfru_diagnostics.Load<uint>(_5540 * 4 + 0) & 32u) != 0u)
                {
                    _11663 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11662;
                    if ((rw_nfru_diagnostics.Load<uint>(_5540 * 4 + 0) & 16u) != 0u)
                    {
                        _11662 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5565 = ((rw_nfru_diagnostics.Load<uint>(_5540 * 4 + 0) & 64u) != 0u).xxx;
                        _11662 = float3(_5565.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5565.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5565.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11663 = _11662;
                }
                _11695 = _11663;
            }
            else
            {
                float3 _11696;
                if (_5064 == 11u)
                {
                    uint _5578 = (rw_nfru_diagnostics.Load<uint>(_5540 * 4 + 0) >> 8u) & 15u;
                    uint _5581 = (rw_nfru_diagnostics.Load<uint>(_5540 * 4 + 0) >> 12u) & 15u;
                    float3 _11655;
                    if ((_5544 == 2u) || (_5544 == 3u))
                    {
                        _11655 = _3274[_5544];
                    }
                    else
                    {
                        bool _5593 = _5578 == 3u;
                        bool _5595 = _5581 == 3u;
                        float3 _11656;
                        if (_5593 && _5595)
                        {
                            _11656 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11657;
                            if (_5593)
                            {
                                _11657 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11658;
                                if (_5595)
                                {
                                    _11658 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11659;
                                    if ((_5578 == 4u) || (_5581 == 4u))
                                    {
                                        _11659 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11660;
                                        if ((_5578 == 1u) || (_5581 == 1u))
                                        {
                                            _11660 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _11920 = (_5544 == 1u).xxx;
                                            _11660 = float3(_11920.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _11920.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _11920.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _11659 = _11660;
                                    }
                                    _11658 = _11659;
                                }
                                _11657 = _11658;
                            }
                            _11656 = _11657;
                        }
                        _11655 = _11656;
                    }
                    _11696 = _11655;
                }
                else
                {
                    _11696 = _3274[min(_5544, 7u)];
                }
                _11695 = _11696;
            }
            _11664 = _11695;
        }
        else
        {
            _11664 = _11665;
        }
        float4 _11699;
        if ((_5064 >= 14u) && (_5064 <= 16u))
        {
            float2 _11697;
            if (_5064 == 14u)
            {
                uint _5651_dummy_parameter;
                uint _5657_dummy_parameter;
                _11697 = r_flow_tm1.Load(int3(clamp(int2(floor(_3948 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5651_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5657_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11698;
                if (_5064 == 16u)
                {
                    uint _9447 = r_warped_flow_qdata_tm1.Load(int3(_3964, 0)).x & 2147483647u;
                    uint _9479 = uint(max((int((_9447 >> 16u) & 15u) - 6), 0));
                    _11698 = ((float2(float((1 - (2 * int((_9447 >> 15u) & 1u))) * int(((_9447 >> uint(7)) & 127u) << _9479)), float((1 - (2 * int((_9447 >> 14u) & 1u))) * int((_9447 & 127u) << _9479))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11698 = _5847 * float2(cbFI_DisplaySize);
                }
                _11697 = _11698;
            }
            uint2 _5690 = uint2(clamp(round(_11697 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5692 = _5690.x;
            uint _5699 = _5690.y;
            _11699 = float4(float(_5692 & 255u), float((_5692 >> 8u) | ((_5699 & 15u) << 4u)), float(_5699 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11700;
            if (_5064 == 17u)
            {
                _11700 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3964, 0)).x != 0u), _4307, 0.0f, 1.0f);
            }
            else
            {
                _11700 = float4(_11664, 1.0f);
            }
            _11699 = _11700;
        }
        rw_output[_3561] = _11699.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5743 = ((uint(_3561.y) * uint(cbFI_DisplaySize.x)) + uint(_3561.x)) * 6u;
            uint _9525 = spvPackHalf2x16(clamp(_6551.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5743 * 4 + 0, (((_9525 & 32767u) >> 4u) | ((((_9525 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6551.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9560 = spvPackHalf2x16(clamp(_6559.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5743 + 1u) * 4 + 0, (((_9560 & 32767u) >> 4u) | ((((_9560 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6559.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9595 = spvPackHalf2x16(clamp(_6567.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5743 + 2u) * 4 + 0, (((_9595 & 32767u) >> 4u) | ((((_9595 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6567.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9630 = spvPackHalf2x16(clamp(_6575.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5743 + 3u) * 4 + 0, (((_9630 & 32767u) >> 4u) | ((((_9630 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6575.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9657 = r_current_interpolation_source.Load(int3(_3561, 0));
            uint _9671 = spvPackHalf2x16(clamp(_9657.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5743 + 4u) * 4 + 0, (((_9671 & 32767u) >> 4u) | ((((_9671 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9657.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11733;
            if (_11575 || (_5064 != 0u))
            {
                _11733 = 4294967295u;
            }
            else
            {
                uint _9706 = spvPackHalf2x16(clamp(_11699.xy, 0.0f.xx, 65000.0f.xx));
                _11733 = (((_9706 & 32767u) >> 4u) | ((((_9706 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11699.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5743 + 5u) * 4 + 0, _11733);
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
