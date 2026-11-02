static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3115[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3419 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3419.x >= cbFI_DisplaySize.x, _3419.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3419] = float4(r_present_backbuffer.Load(int3(_3419, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3419] = float4(r_current_interpolation_source.Load(int3(_3419, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3794 = (float2(_3419) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3805 = int2(floor(_3794 * float2(cbFI_MvDepthLaneSize)));
        int2 _3810 = int2(floor(_3794 * float2(cbFI_FlowLaneSize)));
        float4 _5564 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3794 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5570 = r_warped_filled_flow_tm1.Load(int3(_3810, 0)).xy;
        float2 _5576 = r_warped_filled_motion_tp1.Load(int3(_3805, 0)).xy;
        bool _5598 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9126;
        if (_5598)
        {
            float _5611 = ((2.0f * _3794.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9126 = float2(atan(_5611) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3794.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5611 * _5611))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9126 = _3794;
        }
        bool _3831 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9147;
        bool _9168;
        int2 _9179;
        float3 _10246;
        if (_3831)
        {
            float _9128;
            float _9130;
            _9130 = 2.0f;
            _9128 = -1.0f;
            uint _3483[9];
            float _10640;
            float _10643;
            for (int _9127 = 0; _9127 < 9; _9130 = _10643, _9128 = _10640, _9127++)
            {
                _3483[_9127] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3805 + int2((_9127 % 3) - 1, (_9127 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3483[_9127] != 0u)
                {
                    float _10635;
                    if (_3483[_9127] == 0u)
                    {
                        _10635 = -1.0f;
                    }
                    else
                    {
                        _10635 = float((_3483[_9127] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10643 = min(_9130, _10635);
                    _10640 = max(_9128, _10635);
                }
                else
                {
                    _10643 = _9130;
                    _10640 = _9128;
                }
            }
            float _3877 = float(_9128 >= 0.0f);
            float3 _8937 = 0.0f.xxx;
            _8937.y = _3877;
            float2 _9148;
            bool _9169;
            int2 _9180;
            float3 _10247;
            if ((_9128 - _9130) > 0.0199999995529651641845703125f)
            {
                float _9136;
                int2 _9137;
                float2 _9138;
                int2 _9140;
                float2 _9146;
                _9146 = _5576;
                _9140 = _3805;
                _9138 = _5576;
                _9137 = _3805;
                _9136 = -1.0f;
                float _10648;
                int2 _10652;
                float2 _10663;
                int2 _10674;
                float2 _10707;
                float _10753;
                int _9135 = 0;
                float _10616 = 1000000000.0f;
                for (; _9135 < 9; _10616 = _10753, _9146 = _10707, _9140 = _10674, _9138 = _10663, _9137 = _10652, _9136 = _10648, _9135++)
                {
                    if (_3483[_9135] == 0u)
                    {
                        _10753 = _10616;
                        _10707 = _9146;
                        _10674 = _9140;
                        _10663 = _9138;
                        _10652 = _9137;
                        _10648 = _9136;
                        continue;
                    }
                    int2 _3912 = clamp(_3805 + int2((_9135 % 3) - 1, (_9135 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5686 = _3483[_9135] & 2147483647u;
                    uint _5718 = uint(max((int((_5686 >> 16u) & 15u) - 6), 0));
                    float2 _3918 = (float2(float((1 - (2 * int((_5686 >> 15u) & 1u))) * int(((_5686 >> uint(7)) & 127u) << _5718)), float((1 - (2 * int((_5686 >> 14u) & 1u))) * int((_5686 & 127u) << _5718))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10602;
                    if (_3483[_9135] == 0u)
                    {
                        _10602 = -1.0f;
                    }
                    else
                    {
                        _10602 = float((_3483[_9135] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3923 = _10602 - 0.100000001490116119384765625f;
                    float2 _10603;
                    if (_5598)
                    {
                        float2 _5795 = clamp((((_9126 + (_3918 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5798 = tan(_5795.x);
                        _10603 = (float2(_5798 / cbFI_DeviceToViewDepth.z, (tan(_5795.y) * sqrt(1.0f + (_5798 * _5798))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10603 = _9126 + (_3918 * cbFI_Timestep);
                    }
                    float _3930 = cbFI_Timestep - 1.0f;
                    float2 _10604;
                    if (_5598)
                    {
                        float2 _5866 = clamp((((_9126 + (_3918 * _3930)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5869 = tan(_5866.x);
                        _10604 = (float2(_5869 / cbFI_DeviceToViewDepth.z, (tan(_5866.y) * sqrt(1.0f + (_5869 * _5869))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10604 = _9126 + (_3918 * _3930);
                    }
                    bool _5902 = all(bool2(_10603.x > 0.0f.xx.x, _10603.y > 0.0f.xx.y));
                    bool _5908;
                    if (_5902)
                    {
                        _5908 = all(bool2(_10603.x < 1.0f.xx.x, _10603.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5908 = _5902;
                    }
                    float _10607;
                    if (_5908)
                    {
                        uint _5915_dummy_parameter;
                        _10607 = max((_3923 - (log((r_depth_tm1.Load(int3(int2(floor(_10603 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5915_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10607 = 0.0f;
                    }
                    bool _5945 = all(bool2(_10604.x > 0.0f.xx.x, _10604.y > 0.0f.xx.y));
                    bool _5951;
                    if (_5945)
                    {
                        _5951 = all(bool2(_10604.x < 1.0f.xx.x, _10604.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5951 = _5945;
                    }
                    float _10608;
                    if (_5951)
                    {
                        uint _5958_dummy_parameter;
                        _10608 = _10607 + max((_3923 - (log((r_depth_tp1.Load(int3(int2(floor(_10604 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5958_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10608 = _10607;
                    }
                    float _10649;
                    int2 _10653;
                    float2 _10664;
                    int2 _10675;
                    float2 _10708;
                    float _10754;
                    if (_10608 == 0.0f)
                    {
                        bool _3965 = _3923 > _9136;
                        bool2 _10762 = _3965.xx;
                        _10754 = _10616;
                        _10708 = float2(_10762.x ? _3918.x : _9146.x, _10762.y ? _3918.y : _9146.y);
                        _10675 = int2(_10762.x ? _3912.x : _9140.x, _10762.y ? _3912.y : _9140.y);
                        _10664 = _9138;
                        _10653 = _9137;
                        _10649 = _3965 ? _3923 : _9136;
                    }
                    else
                    {
                        bool _3974 = _10608 < _10616;
                        bool2 _10758 = _3974.xx;
                        _10754 = _3974 ? _10608 : _10616;
                        _10708 = _9146;
                        _10675 = _9140;
                        _10664 = float2(_10758.x ? _3918.x : _9138.x, _10758.y ? _3918.y : _9138.y);
                        _10653 = int2(_10758.x ? _3912.x : _9137.x, _10758.y ? _3912.y : _9137.y);
                        _10649 = _9136;
                    }
                    _10753 = _10754;
                    _10707 = _10708;
                    _10674 = _10675;
                    _10663 = _10664;
                    _10652 = _10653;
                    _10648 = _10649;
                }
                bool _3986 = _9136 < 0.0f;
                bool2 _10768 = _3986.xx;
                int2 _10771 = int2(_10768.x ? _9137.x : _9140.x, _10768.y ? _9137.y : _9140.y);
                _10247 = float3(1.0f, _3877, float(any(bool2(_10771.x != _3805.x, _10771.y != _3805.y))));
                _9180 = _10771;
                _9169 = _3986 ? false : true;
                _9148 = float2(_10768.x ? _9138.x : _9146.x, _10768.y ? _9138.y : _9146.y);
            }
            else
            {
                _10247 = _8937;
                _9180 = _3805;
                _9169 = false;
                _9148 = _5576;
            }
            _10246 = _10247;
            _9179 = _9180;
            _9168 = _9169;
            _9147 = _9148;
        }
        else
        {
            _10246 = 0.0f.xxx;
            _9179 = _3805;
            _9168 = false;
            _9147 = _5576;
        }
        float2 _9149;
        if (_5598)
        {
            float2 _6023 = clamp((((_9126 + (_9147 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6026 = tan(_6023.x);
            _9149 = (float2(_6026 / cbFI_DeviceToViewDepth.z, (tan(_6023.y) * sqrt(1.0f + (_6026 * _6026))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9149 = _9126 + (_9147 * cbFI_Timestep);
        }
        float _4009 = cbFI_Timestep - 1.0f;
        float2 _9151;
        if (_5598)
        {
            float2 _6094 = clamp((((_9126 + (_9147 * _4009)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6097 = tan(_6094.x);
            _9151 = (float2(_6097 / cbFI_DeviceToViewDepth.z, (tan(_6094.y) * sqrt(1.0f + (_6097 * _6097))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9151 = _9126 + (_9147 * _4009);
        }
        float _4014 = -cbFI_Timestep;
        float2 _9152;
        if (_5598)
        {
            float2 _6165 = clamp((((_9126 + (_5570 * _4014)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6168 = tan(_6165.x);
            _9152 = (float2(_6168 / cbFI_DeviceToViewDepth.z, (tan(_6165.y) * sqrt(1.0f + (_6168 * _6168))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9152 = _9126 + (_5570 * _4014);
        }
        float _4019 = 1.0f - cbFI_Timestep;
        float2 _9153;
        if (_5598)
        {
            float2 _6236 = clamp((((_9126 + (_5570 * _4019)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6239 = tan(_6236.x);
            _9153 = (float2(_6239 / cbFI_DeviceToViewDepth.z, (tan(_6236.y) * sqrt(1.0f + (_6239 * _6239))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9153 = _9126 + (_5570 * _4019);
        }
        float4 _6274 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9149, 0.0f);
        float3 _6275 = _6274.xyz;
        float4 _6282 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9151, 0.0f);
        float3 _6283 = _6282.xyz;
        float4 _6290 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9152, 0.0f);
        float3 _6291 = _6290.xyz;
        float4 _6298 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9153, 0.0f);
        float3 _6299 = _6298.xyz;
        float4 _6313 = exp(_5564 - max(max(max(_5564.x, _5564.y), _5564.z), _5564.w).xxxx);
        float4 _6320 = _6313 / (dot(_6313, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4038 = _3831 && (!_9168);
        bool _4047;
        if (_4038)
        {
            _4047 = (_6320.z + _6320.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4047 = _4038;
        }
        bool _4058;
        if (_4047)
        {
            _4058 = length((_9152 - _9149) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4058 = _4047;
        }
        bool _9192;
        if (_4058)
        {
            uint4 _6339 = r_warped_motion_qdata_tp1.Load(int3(_9179, 0));
            uint _6340 = _6339.x;
            bool _9195;
            if (_6340 != 0u)
            {
                float _9181;
                if (_6340 == 0u)
                {
                    _9181 = -1.0f;
                }
                else
                {
                    _9181 = float((_6340 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4068 = _9181 - 0.12000000476837158203125f;
                bool _6359 = all(bool2(_9152.x > 0.0f.xx.x, _9152.y > 0.0f.xx.y));
                bool _6365;
                if (_6359)
                {
                    _6365 = all(bool2(_9152.x < 1.0f.xx.x, _9152.y < 1.0f.xx.y));
                }
                else
                {
                    _6365 = _6359;
                }
                bool _4078;
                if (_6365)
                {
                    uint _6372_dummy_parameter;
                    _4078 = (log((r_depth_tm1.Load(int3(int2(floor(_9152 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6372_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4068;
                }
                else
                {
                    _4078 = _6365;
                }
                bool _4092;
                if (!_4078)
                {
                    bool _6402 = all(bool2(_9153.x > 0.0f.xx.x, _9153.y > 0.0f.xx.y));
                    bool _6408;
                    if (_6402)
                    {
                        _6408 = all(bool2(_9153.x < 1.0f.xx.x, _9153.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6408 = _6402;
                    }
                    bool _4090;
                    if (_6408)
                    {
                        uint _6415_dummy_parameter;
                        _4090 = (log((r_depth_tp1.Load(int3(int2(floor(_9153 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6415_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4068;
                    }
                    else
                    {
                        _4090 = _6408;
                    }
                    _4092 = _4090;
                }
                else
                {
                    _4092 = _4078;
                }
                _9195 = _4092;
            }
            else
            {
                _9195 = false;
            }
            _9192 = _9195;
        }
        else
        {
            _9192 = false;
        }
        bool _4097 = _9168 || _9192;
        bool _4102;
        if (_4097)
        {
            bool _6445 = all(bool2(_9149.x > 0.0f.xx.x, _9149.y > 0.0f.xx.y));
            bool _6451;
            if (_6445)
            {
                _6451 = all(bool2(_9149.x < 1.0f.xx.x, _9149.y < 1.0f.xx.y));
            }
            else
            {
                _6451 = _6445;
            }
            _4102 = _6451;
        }
        else
        {
            _4102 = _4097;
        }
        bool _4107;
        if (_4102)
        {
            bool _6456 = all(bool2(_9151.x > 0.0f.xx.x, _9151.y > 0.0f.xx.y));
            bool _6462;
            if (_6456)
            {
                _6462 = all(bool2(_9151.x < 1.0f.xx.x, _9151.y < 1.0f.xx.y));
            }
            else
            {
                _6462 = _6456;
            }
            _4107 = _6462;
        }
        else
        {
            _4107 = _4102;
        }
        float4 _9289;
        if (_4107)
        {
            float _4110 = _6320.x;
            float _4112 = _6320.y;
            float _4113 = _4110 + _4112;
            float _4118 = _6320.z + _6320.w;
            float _9210;
            if (_4113 > 0.001000000047497451305389404296875f)
            {
                _9210 = _4110 / _4113;
            }
            else
            {
                _9210 = _4019;
            }
            _9289 = float4(_4110 + (_4118 * _9210), _4112 + (_4118 * (1.0f - _9210)), 0.0f, 0.0f);
        }
        else
        {
            _9289 = _6320;
        }
        bool _6490 = (cbFI_pad0 & 1024u) != 0u;
        bool _6466 = !_6490;
        bool _6467 = !_6466;
        bool _6484;
        if (_6467)
        {
            _6484 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9179.y * cbFI_MvDepthLaneSize.x) + _9179.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6484 = _6466;
        }
        bool _6516;
        if (_6467)
        {
            _6516 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3810.y * cbFI_FlowLaneSize.x) + _3810.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6516 = _6466;
        }
        float _4153 = float(_6516);
        bool _9302;
        float4 _9333;
        float3 _10100;
        if (_6490)
        {
            bool _4163;
            if (_6484)
            {
                _4163 = all(bool2(_9149.x > 0.0f.xx.x, _9149.y > 0.0f.xx.y));
            }
            else
            {
                _4163 = _6484;
            }
            bool _4169;
            if (_4163)
            {
                _4169 = all(bool2(_9149.x < 1.0f.xx.x, _9149.y < 1.0f.xx.y));
            }
            else
            {
                _4169 = _4163;
            }
            bool _4176;
            if (_6484)
            {
                _4176 = all(bool2(_9151.x > 0.0f.xx.x, _9151.y > 0.0f.xx.y));
            }
            else
            {
                _4176 = _6484;
            }
            bool _4182;
            if (_4176)
            {
                _4182 = all(bool2(_9151.x < 1.0f.xx.x, _9151.y < 1.0f.xx.y));
            }
            else
            {
                _4182 = _4176;
            }
            bool _4189;
            if (_6516)
            {
                _4189 = all(bool2(_9152.x > 0.0f.xx.x, _9152.y > 0.0f.xx.y));
            }
            else
            {
                _4189 = _6516;
            }
            bool _4195;
            if (_4189)
            {
                _4195 = all(bool2(_9152.x < 1.0f.xx.x, _9152.y < 1.0f.xx.y));
            }
            else
            {
                _4195 = _4189;
            }
            bool _4202;
            if (_6516)
            {
                _4202 = all(bool2(_9153.x > 0.0f.xx.x, _9153.y > 0.0f.xx.y));
            }
            else
            {
                _4202 = _6516;
            }
            bool _4208;
            if (_4202)
            {
                _4208 = all(bool2(_9153.x < 1.0f.xx.x, _9153.y < 1.0f.xx.y));
            }
            else
            {
                _4208 = _4202;
            }
            bool _4210 = !_6484;
            if (_4210)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6558;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6558);
                }
            }
            bool _4215 = !_6516;
            if (_4215)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6568;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6568);
                }
            }
            if (_6484 && _4215)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6578;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6578);
                }
            }
            if (_4210 && _6516)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6588;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6588);
                }
            }
            float _4234 = float(_4169);
            float _4236 = float(_4182);
            bool _4239 = _4195 && _4208;
            float _9244;
            if (_4239)
            {
                _9244 = 1.0f;
            }
            else
            {
                _9244 = (_4195 || _4208) ? 0.5f : 0.0f;
            }
            bool _9249;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4169)) && (!_4182))
            {
                bool _4269;
                if (_4239)
                {
                    float _9247;
                    do
                    {
                        bool _6672 = all(bool2(_9152.x > 0.0f.xx.x, _9152.y > 0.0f.xx.y));
                        bool _6678;
                        if (_6672)
                        {
                            _6678 = all(bool2(_9152.x < 1.0f.xx.x, _9152.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6678 = _6672;
                        }
                        bool _6609 = !_6678;
                        bool _6616;
                        if (!_6609)
                        {
                            bool _6683 = all(bool2(_9153.x > 0.0f.xx.x, _9153.y > 0.0f.xx.y));
                            bool _6689;
                            if (_6683)
                            {
                                _6689 = all(bool2(_9153.x < 1.0f.xx.x, _9153.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6689 = _6683;
                            }
                            _6616 = !_6689;
                        }
                        else
                        {
                            _6616 = _6609;
                        }
                        if (_6616)
                        {
                            _9247 = 0.0f;
                            break;
                        }
                        uint _6696_dummy_parameter;
                        uint _6712_dummy_parameter;
                        float4 _6637 = mul(float4((float2(_9152.x, 1.0f - _9152.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9152 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6696_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6639 = _6637.w;
                        if (abs(_6639) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9247 = 0.0f;
                            break;
                        }
                        float _6650 = abs(cbFI_DeviceToViewDepth.y / ((_6637.z / _6639) - cbFI_DeviceToViewDepth.x));
                        float _6653 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9153 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6712_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9247 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6650 - _6653) / max(max(_6650, _6653), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4269 = _9247 >= 0.5f;
                }
                else
                {
                    _4269 = _4239;
                }
                bool _4277;
                if (_4269)
                {
                    _4277 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4277 = _4269;
                }
                bool _9250;
                if (_4277)
                {
                    uint _6762_dummy_parameter;
                    float2 _9248;
                    do
                    {
                        float _6788 = 1.0f - _9152.y;
                        float4 _6799 = mul(float4((float2(_9152.x, _6788) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9152 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6762_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6801 = _6799.w;
                        if (!(_6801 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9248 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6814 = ((_6799.xy / _6801.xx) + 1.0f.xx) * 0.5f;
                        _9248 = float2(_6814.x - _9152.x, _6788 - _6814.y);
                        break;
                    } while(false);
                    float2 _4290 = float2(cbFI_DisplaySize);
                    _9250 = length(((_9152 + _9248) - _9153) * _4290) <= ((0.100000001490116119384765625f * length(_9248 * _4290)) + 8.0f);
                }
                else
                {
                    _9250 = _4269;
                }
                _9249 = _9250;
            }
            else
            {
                _9249 = true;
            }
            bool _4304 = !_9249;
            bool _10772 = _4304 ? false : _4208;
            bool _10773 = _4304 ? false : _4195;
            bool _9303;
            float4 _9334;
            if (!(((_4169 && _4182) && _10773) && _10772))
            {
                float4 _4326 = _9289 * float4(_4234, _4236, float(_10773), float(_10772));
                float _4328 = dot(_4326, 1.0f.xxxx);
                bool _4331 = !(_4328 > 0.0f);
                float4 _9335;
                if (!_4331)
                {
                    _9335 = _4326 / _4328.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6836;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6836);
                    }
                    _9335 = 0.0f.xxxx;
                }
                _9334 = _9335;
                _9303 = _4331;
            }
            else
            {
                _9334 = _9289;
                _9303 = false;
            }
            _10100 = float3(_4234, _4236, _9244);
            _9333 = _9334;
            _9302 = _9303;
        }
        else
        {
            _10100 = float3(float(_6484), _4153, 0.0f);
            _9333 = _9289;
            _9302 = false;
        }
        float4 _9827;
        bool _9847;
        float3 _9961;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9302))
        {
            bool _4354 = _9333.x > 0.00999999977648258209228515625f;
            bool _4357 = _9333.y > 0.00999999977648258209228515625f;
            bool _4366 = (_9333.z + _9333.w) > 0.0199999995529651641845703125f;
            bool _4372;
            if (_4366)
            {
                bool _6842 = all(bool2(_9152.x > 0.0f.xx.x, _9152.y > 0.0f.xx.y));
                bool _6848;
                if (_6842)
                {
                    _6848 = all(bool2(_9152.x < 1.0f.xx.x, _9152.y < 1.0f.xx.y));
                }
                else
                {
                    _6848 = _6842;
                }
                _4372 = _6848;
            }
            else
            {
                _4372 = _4366;
            }
            bool _4377;
            if (_4372)
            {
                bool _6853 = all(bool2(_9153.x > 0.0f.xx.x, _9153.y > 0.0f.xx.y));
                bool _6859;
                if (_6853)
                {
                    _6859 = all(bool2(_9153.x < 1.0f.xx.x, _9153.y < 1.0f.xx.y));
                }
                else
                {
                    _6859 = _6853;
                }
                _4377 = _6859;
            }
            else
            {
                _4377 = _4372;
            }
            bool _4384;
            if (_4377)
            {
                float _9337;
                do
                {
                    bool _6942 = all(bool2(_9152.x > 0.0f.xx.x, _9152.y > 0.0f.xx.y));
                    bool _6948;
                    if (_6942)
                    {
                        _6948 = all(bool2(_9152.x < 1.0f.xx.x, _9152.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6948 = _6942;
                    }
                    bool _6879 = !_6948;
                    bool _6886;
                    if (!_6879)
                    {
                        bool _6953 = all(bool2(_9153.x > 0.0f.xx.x, _9153.y > 0.0f.xx.y));
                        bool _6959;
                        if (_6953)
                        {
                            _6959 = all(bool2(_9153.x < 1.0f.xx.x, _9153.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6959 = _6953;
                        }
                        _6886 = !_6959;
                    }
                    else
                    {
                        _6886 = _6879;
                    }
                    if (_6886)
                    {
                        _9337 = 0.0f;
                        break;
                    }
                    uint _6966_dummy_parameter;
                    uint _6982_dummy_parameter;
                    float4 _6907 = mul(float4((float2(_9152.x, 1.0f - _9152.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9152 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6966_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6909 = _6907.w;
                    if (abs(_6909) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9337 = 0.0f;
                        break;
                    }
                    float _6920 = abs(cbFI_DeviceToViewDepth.y / ((_6907.z / _6909) - cbFI_DeviceToViewDepth.x));
                    float _6923 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9153 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6982_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9337 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6920 - _6923) / max(max(_6920, _6923), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4384 = _9337 < 0.5f;
            }
            else
            {
                _4384 = _4377;
            }
            float4 _9352;
            if (_4384)
            {
                uint _7032_dummy_parameter;
                uint _7063_dummy_parameter;
                float4 _9353;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9152 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7032_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9153 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7063_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9353 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9353 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9352 = _9353;
            }
            else
            {
                _9352 = 1.0f.xxxx;
            }
            bool _4408;
            if (_6484)
            {
                bool _7092 = all(bool2(_9149.x > 0.0f.xx.x, _9149.y > 0.0f.xx.y));
                bool _7098;
                if (_7092)
                {
                    _7098 = all(bool2(_9149.x < 1.0f.xx.x, _9149.y < 1.0f.xx.y));
                }
                else
                {
                    _7098 = _7092;
                }
                _4408 = _7098;
            }
            else
            {
                _4408 = _6484;
            }
            bool _4414;
            if (_6484)
            {
                bool _7103 = all(bool2(_9151.x > 0.0f.xx.x, _9151.y > 0.0f.xx.y));
                bool _7109;
                if (_7103)
                {
                    _7109 = all(bool2(_9151.x < 1.0f.xx.x, _9151.y < 1.0f.xx.y));
                }
                else
                {
                    _7109 = _7103;
                }
                _4414 = _7109;
            }
            else
            {
                _4414 = _6484;
            }
            bool _4420;
            if (_6516)
            {
                bool _7114 = all(bool2(_9152.x > 0.0f.xx.x, _9152.y > 0.0f.xx.y));
                bool _7120;
                if (_7114)
                {
                    _7120 = all(bool2(_9152.x < 1.0f.xx.x, _9152.y < 1.0f.xx.y));
                }
                else
                {
                    _7120 = _7114;
                }
                _4420 = _7120;
            }
            else
            {
                _4420 = _6516;
            }
            bool _4426;
            if (_6516)
            {
                bool _7125 = all(bool2(_9153.x > 0.0f.xx.x, _9153.y > 0.0f.xx.y));
                bool _7131;
                if (_7125)
                {
                    _7131 = all(bool2(_9153.x < 1.0f.xx.x, _9153.y < 1.0f.xx.y));
                }
                else
                {
                    _7131 = _7125;
                }
                _4426 = _7131;
            }
            else
            {
                _4426 = _6516;
            }
            bool _4429 = _4420 != _4426;
            bool _4435;
            if (_4429)
            {
                _4435 = _4408 || _4414;
            }
            else
            {
                _4435 = _4429;
            }
            float4 _9435;
            if (_4435)
            {
                float4 _9022 = _9352;
                _9022.z = 0.0f;
                _9022.w = 0.0f;
                _9435 = _9022;
            }
            else
            {
                _9435 = _9352;
            }
            bool _4442 = _4408 && _4354;
            bool _4445 = _4414 && _4357;
            float4 _9540;
            float3 _10000;
            if (_4442 || _4445)
            {
                float _9430;
                do
                {
                    uint4 _7270 = r_warped_motion_qdata_tp1.Load(int3(_9179, 0));
                    uint _7271 = _7270.x;
                    if (_7271 != 0u)
                    {
                        float _9429;
                        if (_7271 == 0u)
                        {
                            _9429 = -1.0f;
                        }
                        else
                        {
                            _9429 = float((_7271 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9430 = _9429;
                        break;
                    }
                    int _9412;
                    uint _9413;
                    _9413 = _7271;
                    _9412 = -1;
                    uint _9428;
                    for (; _9412 <= 1; _9413 = _9428, _9412++)
                    {
                        _9428 = _9413;
                        for (int _9426 = -1; _9426 <= 1; )
                        {
                            _9428 = max(_9428, r_warped_motion_qdata_tp1.Load(int3(clamp(_9179 + int2(_9426, _9412), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9426++;
                            continue;
                        }
                    }
                    if (_9413 != 0u)
                    {
                        float _9425;
                        if (_9413 == 0u)
                        {
                            _9425 = -1.0f;
                        }
                        else
                        {
                            _9425 = float((_9413 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9430 = _9425;
                        break;
                    }
                    uint _9415;
                    _9415 = 4294967295u;
                    uint _10744;
                    for (int _9414 = 0; _9414 < 8; _9415 = _10744, _9414++)
                    {
                        int _9418 = 0;
                        for (;;)
                        {
                            if (_9418 < 5)
                            {
                                int2 _7221 = _9179 + (_1093[_9414] * _1102[_9418].xx);
                                bool _7224 = any(bool2(_7221.x < int2(0, 0).x, _7221.y < int2(0, 0).y));
                                bool _7232;
                                if (!_7224)
                                {
                                    _7232 = any(bool2(_7221.x >= cbFI_MvDepthLaneSize.x, _7221.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7232 = _7224;
                                }
                                if (_7232)
                                {
                                    _10744 = _9415;
                                    break;
                                }
                                uint4 _7310 = r_warped_motion_qdata_tp1.Load(int3(_7221, 0));
                                uint _7311 = _7310.x;
                                if (_7311 != 0u)
                                {
                                    _10744 = min(_9415, _7311);
                                    break;
                                }
                                _9418++;
                                continue;
                            }
                            else
                            {
                                _10744 = _9415;
                                break;
                            }
                        }
                    }
                    float _9417;
                    if (_9415 == 4294967295u)
                    {
                        _9417 = -1.0f;
                    }
                    else
                    {
                        float _9416;
                        if (_9415 == 0u)
                        {
                            _9416 = -1.0f;
                        }
                        else
                        {
                            _9416 = float((_9415 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9417 = _9416;
                    }
                    _9430 = _9417;
                    break;
                } while(false);
                bool _4453 = _9430 < 0.0f;
                float _9431;
                if (_4453)
                {
                    _9431 = 0.0f;
                }
                else
                {
                    _9431 = _9430 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _7332_dummy_parameter;
                uint _7364_dummy_parameter;
                float4 _9468;
                if ((_4453 && _4442) && _4445)
                {
                    uint _7396_dummy_parameter;
                    float _7420 = log((r_depth_tm1.Load(int3(int2(floor(_9149 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7396_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7428_dummy_parameter;
                    float _7452 = log((r_depth_tp1.Load(int3(int2(floor(_9151 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7428_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9469;
                    if (_7420 > (_7452 + 0.07999999821186065673828125f))
                    {
                        float4 _9026 = _9435;
                        _9026.x = 0.0f;
                        _9469 = _9026;
                    }
                    else
                    {
                        float4 _9470;
                        if (_7452 > (_7420 + 0.07999999821186065673828125f))
                        {
                            float4 _9028 = _9435;
                            _9028.y = 0.0f;
                            _9470 = _9028;
                        }
                        else
                        {
                            _9470 = _9435;
                        }
                        _9469 = _9470;
                    }
                    _9468 = _9469;
                }
                else
                {
                    _9468 = _9435;
                }
                float _4505 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4507 = _9430 >= 0.0f;
                float _9451;
                if (_4507)
                {
                    _9451 = _9430 - _4505;
                }
                else
                {
                    float _9447;
                    if (_4442)
                    {
                        float _9446;
                        _9446 = 2.0f;
                        float _7510;
                        for (int _9445 = 0; _9445 < 24; _9446 = _7510, _9445++)
                        {
                            float _7474 = float(_9445 & 7) * 0.785398185253143310546875f;
                            int _7476 = _9445 >> 3;
                            int _9448;
                            if (_7476 == 0)
                            {
                                _9448 = 16;
                            }
                            else
                            {
                                _9448 = (_7476 == 1) ? 48 : 96;
                            }
                            uint _7526_dummy_parameter;
                            _7510 = min(_9446, log((r_depth_tm1.Load(int3(int2(floor(clamp(_9149 + ((cbFI_MvDepthLaneSizeRcp * float(_9448)) * float2(cos(_7474), sin(_7474))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7526_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9447 = _9446;
                    }
                    else
                    {
                        _9447 = 0.0f;
                    }
                    _9451 = _9447;
                }
                float _9458;
                if (_4507)
                {
                    _9458 = _9430 - _4505;
                }
                else
                {
                    float _9454;
                    if (_4445)
                    {
                        float _9453;
                        _9453 = 2.0f;
                        float _7624;
                        for (int _9452 = 0; _9452 < 24; _9453 = _7624, _9452++)
                        {
                            float _7588 = float(_9452 & 7) * 0.785398185253143310546875f;
                            int _7590 = _9452 >> 3;
                            int _9455;
                            if (_7590 == 0)
                            {
                                _9455 = 16;
                            }
                            else
                            {
                                _9455 = (_7590 == 1) ? 48 : 96;
                            }
                            uint _7656_dummy_parameter;
                            _7624 = min(_9453, log((r_depth_tp1.Load(int3(int2(floor(clamp(_9151 + ((cbFI_MvDepthLaneSizeRcp * float(_9455)) * float2(cos(_7588), sin(_7588))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7656_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9454 = _9453;
                    }
                    else
                    {
                        _9454 = 0.0f;
                    }
                    _9458 = _9454;
                }
                float _9459;
                if (_4442)
                {
                    uint _7688_dummy_parameter;
                    _9459 = r_depth_tm1.Load(int3(int2(floor(_9149 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7688_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9459 = 0.0f;
                }
                float _9460;
                if (_4445)
                {
                    uint _7707_dummy_parameter;
                    _9460 = r_depth_tp1.Load(int3(int2(floor(_9151 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7707_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9460 = 0.0f;
                }
                bool _4562;
                if (_4442)
                {
                    _4562 = _9459 > ((exp((_9451 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4562 = _4442;
                }
                float4 _9476;
                if (_4562)
                {
                    float4 _9030 = _9468;
                    _9030.x = 0.0f;
                    _9476 = _9030;
                }
                else
                {
                    _9476 = _9468;
                }
                bool _4574;
                if (_4445)
                {
                    _4574 = _9460 > ((exp((_9458 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4574 = _4445;
                }
                float4 _9478;
                if (_4574)
                {
                    float4 _9032 = _9476;
                    _9032.y = 0.0f;
                    _9478 = _9032;
                }
                else
                {
                    _9478 = _9476;
                }
                float4 _9541;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4507)
                {
                    bool _4594;
                    if (_4442)
                    {
                        _4594 = _9459 < ((exp((_9451 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4594 = _4442;
                    }
                    float4 _9480;
                    if (_4594)
                    {
                        float4 _9034 = _9478;
                        _9034.x = 0.0f;
                        _9480 = _9034;
                    }
                    else
                    {
                        _9480 = _9478;
                    }
                    bool _4606;
                    if (_4445)
                    {
                        _4606 = _9460 < ((exp((_9458 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4606 = _4445;
                    }
                    float4 _9542;
                    if (_4606)
                    {
                        float4 _9036 = _9480;
                        _9036.y = 0.0f;
                        _9542 = _9036;
                    }
                    else
                    {
                        _9542 = _9480;
                    }
                    _9541 = _9542;
                }
                else
                {
                    _9541 = _9478;
                }
                _10000 = float3(_9431, log((r_depth_tm1.Load(int3(int2(floor(_9149 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7332_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_9151 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7364_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _9540 = _9541;
            }
            else
            {
                _10000 = float3(0.0f, 0.0f, 0.5f);
                _9540 = _9435;
            }
            bool _4617 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4366;
            bool _4623;
            if (_4617)
            {
                _4623 = _4420 || _4426;
            }
            else
            {
                _4623 = _4617;
            }
            float4 _9563;
            if (_4623)
            {
                float _9535;
                do
                {
                    uint4 _7886 = r_warped_motion_qdata_tp1.Load(int3(_9179, 0));
                    uint _7887 = _7886.x;
                    if (_7887 != 0u)
                    {
                        float _9534;
                        if (_7887 == 0u)
                        {
                            _9534 = -1.0f;
                        }
                        else
                        {
                            _9534 = float((_7887 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9535 = _9534;
                        break;
                    }
                    int _9517;
                    uint _9518;
                    _9518 = _7887;
                    _9517 = -1;
                    uint _9533;
                    for (; _9517 <= 1; _9518 = _9533, _9517++)
                    {
                        _9533 = _9518;
                        for (int _9531 = -1; _9531 <= 1; )
                        {
                            _9533 = max(_9533, r_warped_motion_qdata_tp1.Load(int3(clamp(_9179 + int2(_9531, _9517), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9531++;
                            continue;
                        }
                    }
                    if (_9518 != 0u)
                    {
                        float _9530;
                        if (_9518 == 0u)
                        {
                            _9530 = -1.0f;
                        }
                        else
                        {
                            _9530 = float((_9518 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9535 = _9530;
                        break;
                    }
                    uint _9520;
                    _9520 = 4294967295u;
                    uint _10745;
                    for (int _9519 = 0; _9519 < 8; _9520 = _10745, _9519++)
                    {
                        int _9523 = 0;
                        for (;;)
                        {
                            if (_9523 < 5)
                            {
                                int2 _7837 = _9179 + (_1093[_9519] * _1102[_9523].xx);
                                bool _7840 = any(bool2(_7837.x < int2(0, 0).x, _7837.y < int2(0, 0).y));
                                bool _7848;
                                if (!_7840)
                                {
                                    _7848 = any(bool2(_7837.x >= cbFI_MvDepthLaneSize.x, _7837.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7848 = _7840;
                                }
                                if (_7848)
                                {
                                    _10745 = _9520;
                                    break;
                                }
                                uint4 _7926 = r_warped_motion_qdata_tp1.Load(int3(_7837, 0));
                                uint _7927 = _7926.x;
                                if (_7927 != 0u)
                                {
                                    _10745 = min(_9520, _7927);
                                    break;
                                }
                                _9523++;
                                continue;
                            }
                            else
                            {
                                _10745 = _9520;
                                break;
                            }
                        }
                    }
                    float _9522;
                    if (_9520 == 4294967295u)
                    {
                        _9522 = -1.0f;
                    }
                    else
                    {
                        float _9521;
                        if (_9520 == 0u)
                        {
                            _9521 = -1.0f;
                        }
                        else
                        {
                            _9521 = float((_9520 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9522 = _9521;
                    }
                    _9535 = _9522;
                    break;
                } while(false);
                float4 _9564;
                if (_9535 >= 0.0f)
                {
                    float _7948 = (exp((_9535 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4642;
                    if (_4420)
                    {
                        uint _7955_dummy_parameter;
                        _4642 = r_depth_tm1.Load(int3(int2(floor(_9152 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7955_dummy_parameter))))), 0)).x > _7948;
                    }
                    else
                    {
                        _4642 = _4420;
                    }
                    float4 _9553;
                    if (_4642)
                    {
                        float4 _9038 = _9540;
                        _9038.z = 0.0f;
                        _9553 = _9038;
                    }
                    else
                    {
                        _9553 = _9540;
                    }
                    bool _4654;
                    if (_4426)
                    {
                        uint _7974_dummy_parameter;
                        _4654 = r_depth_tp1.Load(int3(int2(floor(_9153 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7974_dummy_parameter))))), 0)).x > _7948;
                    }
                    else
                    {
                        _4654 = _4426;
                    }
                    float4 _9565;
                    if (_4654)
                    {
                        float4 _9040 = _9553;
                        _9040.w = 0.0f;
                        _9565 = _9040;
                    }
                    else
                    {
                        _9565 = _9553;
                    }
                    _9564 = _9565;
                }
                else
                {
                    _9564 = _9540;
                }
                _9563 = _9564;
            }
            else
            {
                _9563 = _9540;
            }
            bool _4662 = _4408 != _4414;
            bool _4669;
            if (_4662)
            {
                _4669 = _4408 ? _4354 : _4357;
            }
            else
            {
                _4669 = _4662;
            }
            bool _4676;
            if (_4669)
            {
                _4676 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _4676 = _4669;
            }
            float4 _9648;
            if (_4676)
            {
                bool2 _4681 = _4408.xx;
                float2 _4682 = float2(_4681.x ? _9149.x : _9151.x, _4681.y ? _9149.y : _9151.y);
                float _9555;
                if (_4408)
                {
                    uint _7993_dummy_parameter;
                    _9555 = r_depth_tm1.Load(int3(int2(floor(_4682 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7993_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8009_dummy_parameter;
                    _9555 = r_depth_tp1.Load(int3(int2(floor(_4682 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8009_dummy_parameter))))), 0)).x;
                }
                float4x4 _9556;
                if (_4408)
                {
                    _9556 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9556 = cbFI_MotionTP1ToTM1;
                }
                float2 _9557;
                do
                {
                    float _8036 = _4682.x;
                    float _8039 = 1.0f - _4682.y;
                    float4 _8050 = mul(float4((float2(_8036, _8039) * 2.0f) - 1.0f.xx, _9555, 1.0f), _9556);
                    float _8052 = _8050.w;
                    if (!(_8052 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9557 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8065 = ((_8050.xy / _8052.xx) + 1.0f.xx) * 0.5f;
                    _9557 = float2(_8065.x - _8036, _8039 - _8065.y);
                    break;
                } while(false);
                float2 _4712 = float2(cbFI_DisplaySize);
                float4 _9649;
                if (!(length(((_4682 + _9557) - float2(_4681.x ? _9151.x : _9149.x, _4681.y ? _9151.y : _9149.y)) * _4712) <= ((0.100000001490116119384765625f * length(_9557 * _4712)) + 8.0f)))
                {
                    float4 _9650;
                    if (_4408)
                    {
                        float4 _9050 = _9563;
                        _9050.x = 0.0f;
                        _9650 = _9050;
                    }
                    else
                    {
                        float4 _9052 = _9563;
                        _9052.y = 0.0f;
                        _9650 = _9052;
                    }
                    _9649 = _9650;
                }
                else
                {
                    _9649 = _9563;
                }
                _9648 = _9649;
            }
            else
            {
                _9648 = _9563;
            }
            float4 _4737 = _9333 * _9648;
            float _4739 = dot(_4737, 1.0f.xxxx);
            float4 _9828;
            bool _9848;
            if (_4739 > 0.0f)
            {
                _9848 = _9302;
                _9828 = _4737 / _4739.xxxx;
            }
            else
            {
                bool _4750 = any(bool4(_9648.x < 1.0f.xxxx.x, _9648.y < 1.0f.xxxx.y, _9648.z < 1.0f.xxxx.z, _9648.w < 1.0f.xxxx.w));
                if (_4750)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8087;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8087);
                    }
                }
                bool4 _10775 = _4750.xxxx;
                _9848 = _4750 ? true : _9302;
                _9828 = float4(_10775.x ? 0.0f.xxxx.x : _9333.x, _10775.y ? 0.0f.xxxx.y : _9333.y, _10775.z ? 0.0f.xxxx.z : _9333.z, _10775.w ? 0.0f.xxxx.w : _9333.w);
            }
            _9961 = _10000;
            _9847 = _9848;
            _9827 = _9828;
        }
        else
        {
            _9961 = float3(0.0f, 0.0f, 0.5f);
            _9847 = _9302;
            _9827 = _9333;
        }
        uint _4759 = (cbFI_pad0 >> 24u) & 31u;
        uint _4763 = (cbFI_pad0 >> 16u) & 255u;
        bool _4765 = _4759 != 0u;
        bool _4767 = _4763 == 12u;
        bool _4770 = _4763 == 13u;
        float4 _9844;
        if ((_4765 || _4767) || _4770)
        {
            float _9651;
            do
            {
                bool _8171 = all(bool2(_9152.x > 0.0f.xx.x, _9152.y > 0.0f.xx.y));
                bool _8177;
                if (_8171)
                {
                    _8177 = all(bool2(_9152.x < 1.0f.xx.x, _9152.y < 1.0f.xx.y));
                }
                else
                {
                    _8177 = _8171;
                }
                bool _8108 = !_8177;
                bool _8115;
                if (!_8108)
                {
                    bool _8182 = all(bool2(_9153.x > 0.0f.xx.x, _9153.y > 0.0f.xx.y));
                    bool _8188;
                    if (_8182)
                    {
                        _8188 = all(bool2(_9153.x < 1.0f.xx.x, _9153.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8188 = _8182;
                    }
                    _8115 = !_8188;
                }
                else
                {
                    _8115 = _8108;
                }
                if (_8115)
                {
                    _9651 = 0.0f;
                    break;
                }
                uint _8195_dummy_parameter;
                uint _8211_dummy_parameter;
                float4 _8136 = mul(float4((float2(_9152.x, 1.0f - _9152.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9152 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8195_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8138 = _8136.w;
                if (abs(_8138) < 9.9999999747524270787835121154785e-07f)
                {
                    _9651 = 0.0f;
                    break;
                }
                float _8149 = abs(cbFI_DeviceToViewDepth.y / ((_8136.z / _8138) - cbFI_DeviceToViewDepth.x));
                float _8152 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9153 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8211_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9651 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8149 - _8152) / max(max(_8149, _8152), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8259 = all(bool2(_9153.x > 0.0f.xx.x, _9153.y > 0.0f.xx.y));
            bool _8265;
            if (_8259)
            {
                _8265 = all(bool2(_9153.x < 1.0f.xx.x, _9153.y < 1.0f.xx.y));
            }
            else
            {
                _8265 = _8259;
            }
            float _9652;
            if (_8265)
            {
                uint _8272_dummy_parameter;
                _9652 = length((_5570 + (r_motion_tp1.Load(int3(int2(floor(_9153 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8272_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9652 = 1000000.0f;
            }
            float _9663;
            if ((_4759 & 1u) != 0u)
            {
                _9663 = _9651;
            }
            else
            {
                _9663 = 1.0f;
            }
            float _9664;
            if ((_4759 & 2u) != 0u)
            {
                _9664 = _9663 * (1.0f - smoothstep(2.0f, 8.0f, _9652));
            }
            else
            {
                _9664 = _9663;
            }
            float _9665;
            if ((_4759 & 4u) != 0u)
            {
                _9665 = _9664 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6291 - _6299) - length(_6275 - _6283))));
            }
            else
            {
                _9665 = _9664;
            }
            float _9838;
            if ((_4759 & 8u) != 0u)
            {
                _9838 = lerp(1.0f, _9665, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6275 - _6283)));
            }
            else
            {
                _9838 = _9665;
            }
            bool _4845 = (_4759 & 16u) != 0u;
            bool _4854;
            if (_4845)
            {
                _4854 = length(_9147 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4854 = _4845;
            }
            float _10777 = _4854 ? 1.0f : _9838;
            bool _4860 = _4765 && _6484;
            bool _4865;
            if (_4860)
            {
                bool _8297 = all(bool2(_9149.x > 0.0f.xx.x, _9149.y > 0.0f.xx.y));
                bool _8303;
                if (_8297)
                {
                    _8303 = all(bool2(_9149.x < 1.0f.xx.x, _9149.y < 1.0f.xx.y));
                }
                else
                {
                    _8303 = _8297;
                }
                _4865 = _8303;
            }
            else
            {
                _4865 = _4860;
            }
            bool _4870;
            if (_4865)
            {
                bool _8308 = all(bool2(_9151.x > 0.0f.xx.x, _9151.y > 0.0f.xx.y));
                bool _8314;
                if (_8308)
                {
                    _8314 = all(bool2(_9151.x < 1.0f.xx.x, _9151.y < 1.0f.xx.y));
                }
                else
                {
                    _8314 = _8308;
                }
                _4870 = _8314;
            }
            else
            {
                _4870 = _4865;
            }
            float4 _9845;
            if (_4870)
            {
                float _4876 = _9827.x + _9827.y;
                float _4885 = (_9827.z + _9827.w) * (1.0f - _10777);
                float _9841;
                if (_4876 > 9.9999997473787516355514526367188e-06f)
                {
                    _9841 = _9827.x / _4876;
                }
                else
                {
                    _9841 = _4019;
                }
                _9845 = float4(_9827.x + (_4885 * _9841), _9827.y + (_4885 * (1.0f - _9841)), _9827.zw * _10777);
            }
            else
            {
                _9845 = _9827;
            }
            _9844 = _9845;
        }
        else
        {
            _9844 = _9827;
        }
        float3 _10548;
        if (_9847)
        {
            float3 _8320 = r_current_interpolation_source.Load(int3(_3419, 0)).xyz;
            float3 _10549;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6484)
            {
                uint _8327_dummy_parameter;
                float _9952;
                _9952 = r_depth_tm1.Load(int3(int2(floor(_9149 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8327_dummy_parameter))))), 0)).x;
                float _4997;
                for (int _9951 = 0; _9951 < 24; _9952 = _4997, _9951++)
                {
                    float _4969 = float(_9951 & 7) * 0.785398185253143310546875f;
                    int _4971 = _9951 >> 3;
                    int _10599;
                    if (_4971 == 0)
                    {
                        _10599 = 16;
                    }
                    else
                    {
                        _10599 = (_4971 == 1) ? 48 : 96;
                    }
                    uint _8347_dummy_parameter;
                    _4997 = min(_9952, r_depth_tm1.Load(int3(int2(floor(clamp(_9149 + ((cbFI_MvDepthLaneSizeRcp * float(_10599)) * float2(cos(_4969), sin(_4969))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8347_dummy_parameter))))), 0)).x);
                }
                float2 _9953;
                do
                {
                    float _8369 = 1.0f - _9149.y;
                    float4 _8380 = mul(float4((float2(_9149.x, _8369) * 2.0f) - 1.0f.xx, _9952, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8382 = _8380.w;
                    if (!(_8382 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9953 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8395 = ((_8380.xy / _8382.xx) + 1.0f.xx) * 0.5f;
                    _9953 = float2(_8395.x - _9149.x, _8369 - _8395.y);
                    break;
                } while(false);
                float2 _5008 = _9149 + _9953;
                bool _8413 = all(bool2(_5008.x > 0.0f.xx.x, _5008.y > 0.0f.xx.y));
                bool _8419;
                if (_8413)
                {
                    _8419 = all(bool2(_5008.x < 1.0f.xx.x, _5008.y < 1.0f.xx.y));
                }
                else
                {
                    _8419 = _8413;
                }
                float3 _10550;
                if (_8419)
                {
                    float _5014 = abs(cbFI_DeviceToViewDepth.y / (_9952 - cbFI_DeviceToViewDepth.x));
                    uint _8439_dummy_parameter;
                    int2 _8439 = int2(spvTextureSize(r_depth_m2, uint(0), _8439_dummy_parameter));
                    float _5018 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5008 * float2(_8439))), int2(0, 0), _8439 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10555;
                    if (abs(_5018 - _5014) <= (0.20000000298023223876953125f * max(_5018, _5014)))
                    {
                        uint _8473_dummy_parameter;
                        int2 _8473 = int2(spvTextureSize(r_colour_m2, uint(0), _8473_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8496;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8496);
                        }
                        _10555 = r_colour_m2.Load(int3(clamp(int2(floor(_5008 * float2(_8473))), int2(0, 0), _8473 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8506;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8506);
                        }
                        _10555 = _8320;
                    }
                    _10550 = _10555;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8516;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8516);
                    }
                    _10550 = _8320;
                }
                _10549 = _10550;
            }
            else
            {
                _10549 = _8320;
            }
            _10548 = _10549;
        }
        else
        {
            _10548 = (((_6275 * _9844.x) + (_6283 * _9844.y)) + (_6291 * _9844.z)) + (_6299 * _9844.w);
        }
        uint _5046 = cbFI_pad0 & 255u;
        bool _10440;
        float3 _10547;
        if (_5046 != 0u)
        {
            float3 _5051 = r_present_backbuffer.Load(int3(_3419, 0)).xyz;
            float3 _5055 = r_current_interpolation_source.Load(int3(_3419, 0)).xyz;
            float3 _5059 = abs(_5051 - _5055);
            float3 _9956;
            if (_5046 == 2u)
            {
                _9956 = (abs(_5055) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9956 = 0.000244140625f.xxx;
            }
            bool _5075 = any(bool3(_5059.x > _9956.x, _5059.y > _9956.y, _5059.z > _9956.z));
            bool3 _10778 = _5075.xxx;
            _10547 = float3(_10778.x ? _5051.x : _10548.x, _10778.y ? _5051.y : _10548.y, _10778.z ? _5051.z : _10548.z);
            _10440 = _5075;
        }
        else
        {
            _10547 = _10548;
            _10440 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8531;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8531);
        }
        float3 _10530;
        if (_4763 == 1u)
        {
            _10530 = lerp(_6275, _6283, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10531;
            if (_4763 == 2u)
            {
                _10531 = lerp(_6291, _6299, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10532;
                if (_4763 == 3u)
                {
                    _10532 = float(_10440).xxx;
                }
                else
                {
                    float3 _10533;
                    if (_4763 == 4u)
                    {
                        _10533 = float3(((_9147 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10534;
                        if (_4763 == 5u)
                        {
                            _10534 = float3(((_5570 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10535;
                            if (_4763 == 6u)
                            {
                                _10535 = float3(_9844.xy, _9844.z + _9844.w);
                            }
                            else
                            {
                                float3 _10536;
                                if (_4763 == 7u)
                                {
                                    _10536 = r_current_interpolation_source.Load(int3(_3419, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10537;
                                    if (_4763 == 8u)
                                    {
                                        _10537 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3794, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10538;
                                        if (_4767)
                                        {
                                            uint _8553_dummy_parameter;
                                            uint _8585_dummy_parameter;
                                            _10538 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3794 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8553_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3794 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8585_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10539;
                                            if (_4770)
                                            {
                                                _10539 = _6291;
                                            }
                                            else
                                            {
                                                float3 _10540;
                                                if (_4763 == 20u)
                                                {
                                                    _10540 = _6275;
                                                }
                                                else
                                                {
                                                    float3 _10541;
                                                    if (_4763 == 21u)
                                                    {
                                                        _10541 = _6283;
                                                    }
                                                    else
                                                    {
                                                        float3 _10542;
                                                        if (_4763 == 22u)
                                                        {
                                                            _10542 = _6299;
                                                        }
                                                        else
                                                        {
                                                            float3 _10543;
                                                            if (_4763 == 18u)
                                                            {
                                                                _10543 = _10246;
                                                            }
                                                            else
                                                            {
                                                                float3 _10544;
                                                                if (_4763 == 19u)
                                                                {
                                                                    _10544 = _10100;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10780 = (_4763 == 23u).xxx;
                                                                    _10544 = float3(_10780.x ? _9961.x : _10547.x, _10780.y ? _9961.y : _10547.y, _10780.z ? _9961.z : _10547.z);
                                                                }
                                                                _10543 = _10544;
                                                            }
                                                            _10542 = _10543;
                                                        }
                                                        _10541 = _10542;
                                                    }
                                                    _10540 = _10541;
                                                }
                                                _10539 = _10540;
                                            }
                                            _10538 = _10539;
                                        }
                                        _10537 = _10538;
                                    }
                                    _10536 = _10537;
                                }
                                _10535 = _10536;
                            }
                            _10534 = _10535;
                        }
                        _10533 = _10534;
                    }
                    _10532 = _10533;
                }
                _10531 = _10532;
            }
            _10530 = _10531;
        }
        float3 _10529;
        if ((_4763 >= 9u) && (_4763 <= 11u))
        {
            uint _5239 = 64u + uint((_9179.y * cbFI_MvDepthLaneSize.x) + _9179.x);
            uint _5243 = rw_nfru_diagnostics.Load<uint>(_5239 * 4 + 0) & 15u;
            float3 _10560;
            if (_4763 == 10u)
            {
                float3 _10528;
                if ((rw_nfru_diagnostics.Load<uint>(_5239 * 4 + 0) & 32u) != 0u)
                {
                    _10528 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10527;
                    if ((rw_nfru_diagnostics.Load<uint>(_5239 * 4 + 0) & 16u) != 0u)
                    {
                        _10527 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5264 = ((rw_nfru_diagnostics.Load<uint>(_5239 * 4 + 0) & 64u) != 0u).xxx;
                        _10527 = float3(_5264.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5264.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5264.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10528 = _10527;
                }
                _10560 = _10528;
            }
            else
            {
                float3 _10561;
                if (_4763 == 11u)
                {
                    uint _5277 = (rw_nfru_diagnostics.Load<uint>(_5239 * 4 + 0) >> 8u) & 15u;
                    uint _5280 = (rw_nfru_diagnostics.Load<uint>(_5239 * 4 + 0) >> 12u) & 15u;
                    float3 _10520;
                    if ((_5243 == 2u) || (_5243 == 3u))
                    {
                        _10520 = _3115[_5243];
                    }
                    else
                    {
                        bool _5292 = _5277 == 3u;
                        bool _5294 = _5280 == 3u;
                        float3 _10521;
                        if (_5292 && _5294)
                        {
                            _10521 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10522;
                            if (_5292)
                            {
                                _10522 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10523;
                                if (_5294)
                                {
                                    _10523 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10524;
                                    if ((_5277 == 4u) || (_5280 == 4u))
                                    {
                                        _10524 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10525;
                                        if ((_5277 == 1u) || (_5280 == 1u))
                                        {
                                            _10525 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10782 = (_5243 == 1u).xxx;
                                            _10525 = float3(_10782.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10782.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10782.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10524 = _10525;
                                    }
                                    _10523 = _10524;
                                }
                                _10522 = _10523;
                            }
                            _10521 = _10522;
                        }
                        _10520 = _10521;
                    }
                    _10561 = _10520;
                }
                else
                {
                    _10561 = _3115[min(_5243, 7u)];
                }
                _10560 = _10561;
            }
            _10529 = _10560;
        }
        else
        {
            _10529 = _10530;
        }
        float4 _10564;
        if ((_4763 >= 14u) && (_4763 <= 16u))
        {
            float2 _10562;
            if (_4763 == 14u)
            {
                uint _5350_dummy_parameter;
                uint _5356_dummy_parameter;
                _10562 = r_flow_tm1.Load(int3(clamp(int2(floor(_3794 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5350_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5356_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10563;
                if (_4763 == 16u)
                {
                    uint _8636 = r_warped_flow_qdata_tm1.Load(int3(_3810, 0)).x & 2147483647u;
                    uint _8668 = uint(max((int((_8636 >> 16u) & 15u) - 6), 0));
                    _10563 = ((float2(float((1 - (2 * int((_8636 >> 15u) & 1u))) * int(((_8636 >> uint(7)) & 127u) << _8668)), float((1 - (2 * int((_8636 >> 14u) & 1u))) * int((_8636 & 127u) << _8668))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10563 = _5570 * float2(cbFI_DisplaySize);
                }
                _10562 = _10563;
            }
            uint2 _5389 = uint2(clamp(round(_10562 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5391 = _5389.x;
            uint _5398 = _5389.y;
            _10564 = float4(float(_5391 & 255u), float((_5391 >> 8u) | ((_5398 & 15u) << 4u)), float(_5398 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10565;
            if (_4763 == 17u)
            {
                _10565 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3810, 0)).x != 0u), _4153, 0.0f, 1.0f);
            }
            else
            {
                _10565 = float4(_10529, 1.0f);
            }
            _10564 = _10565;
        }
        rw_output[_3419] = _10564.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5442 = ((uint(_3419.y) * uint(cbFI_DisplaySize.x)) + uint(_3419.x)) * 6u;
            uint _8714 = spvPackHalf2x16(clamp(_6274.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5442 * 4 + 0, (((_8714 & 32767u) >> 4u) | ((((_8714 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6274.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8749 = spvPackHalf2x16(clamp(_6282.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5442 + 1u) * 4 + 0, (((_8749 & 32767u) >> 4u) | ((((_8749 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6282.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8784 = spvPackHalf2x16(clamp(_6290.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5442 + 2u) * 4 + 0, (((_8784 & 32767u) >> 4u) | ((((_8784 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6290.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8819 = spvPackHalf2x16(clamp(_6298.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5442 + 3u) * 4 + 0, (((_8819 & 32767u) >> 4u) | ((((_8819 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6298.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8846 = r_current_interpolation_source.Load(int3(_3419, 0));
            uint _8860 = spvPackHalf2x16(clamp(_8846.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5442 + 4u) * 4 + 0, (((_8860 & 32767u) >> 4u) | ((((_8860 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8846.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10598;
            if (_10440 || (_4763 != 0u))
            {
                _10598 = 4294967295u;
            }
            else
            {
                uint _8895 = spvPackHalf2x16(clamp(_10564.xy, 0.0f.xx, 65000.0f.xx));
                _10598 = (((_8895 & 32767u) >> 4u) | ((((_8895 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10564.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5442 + 5u) * 4 + 0, _10598);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3419] = float4(r_current_interpolation_source.Load(int3(_3419, 0)).xyz, 1.0f).xyz;
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
