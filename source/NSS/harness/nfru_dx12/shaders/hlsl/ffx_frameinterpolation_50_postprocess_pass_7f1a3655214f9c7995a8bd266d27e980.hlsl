static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3273[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3560 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3560.x >= cbFI_DisplaySize.x, _3560.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3560] = float4(r_present_backbuffer.Load(int3(_3560, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3947 = (float2(_3560) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3958 = int2(floor(_3947 * float2(cbFI_MvDepthLaneSize)));
        int2 _3963 = int2(floor(_3947 * float2(cbFI_FlowLaneSize)));
        float4 _5840 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3947 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5846 = r_warped_filled_flow_tm1.Load(int3(_3963, 0)).xy;
        float2 _5852 = r_warped_filled_motion_tp1.Load(int3(_3958, 0)).xy;
        bool _5874 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9930;
        if (_5874)
        {
            float _5887 = ((2.0f * _3947.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9930 = float2(atan(_5887) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3947.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5887 * _5887))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9930 = _3947;
        }
        bool _3984 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9951;
        bool _9972;
        int2 _9983;
        float3 _11336;
        if (_3984)
        {
            float _9932;
            float _9934;
            _9934 = 2.0f;
            _9932 = -1.0f;
            uint _3622[9];
            float _11768;
            float _11771;
            for (int _9931 = 0; _9931 < 9; _9934 = _11771, _9932 = _11768, _9931++)
            {
                _3622[_9931] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3958 + int2((_9931 % 3) - 1, (_9931 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3622[_9931] != 0u)
                {
                    float _11763;
                    if (_3622[_9931] == 0u)
                    {
                        _11763 = -1.0f;
                    }
                    else
                    {
                        _11763 = float((_3622[_9931] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11771 = min(_9934, _11763);
                    _11768 = max(_9932, _11763);
                }
                else
                {
                    _11771 = _9934;
                    _11768 = _9932;
                }
            }
            float _4030 = float(_9932 >= 0.0f);
            float3 _9731 = 0.0f.xxx;
            _9731.y = _4030;
            float2 _9952;
            bool _9973;
            int2 _9984;
            float3 _11337;
            if ((_9932 - _9934) > 0.0199999995529651641845703125f)
            {
                float _9940;
                int2 _9941;
                float2 _9942;
                int2 _9944;
                float2 _9950;
                _9950 = _5852;
                _9944 = _3958;
                _9942 = _5852;
                _9941 = _3958;
                _9940 = -1.0f;
                float _11776;
                int2 _11780;
                float2 _11791;
                int2 _11802;
                float2 _11835;
                float _11882;
                int _9939 = 0;
                float _11744 = 1000000000.0f;
                for (; _9939 < 9; _11744 = _11882, _9950 = _11835, _9944 = _11802, _9942 = _11791, _9941 = _11780, _9940 = _11776, _9939++)
                {
                    if (_3622[_9939] == 0u)
                    {
                        _11882 = _11744;
                        _11835 = _9950;
                        _11802 = _9944;
                        _11791 = _9942;
                        _11780 = _9941;
                        _11776 = _9940;
                        continue;
                    }
                    int2 _4065 = clamp(_3958 + int2((_9939 % 3) - 1, (_9939 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5962 = _3622[_9939] & 2147483647u;
                    uint _5994 = uint(max((int((_5962 >> 16u) & 15u) - 6), 0));
                    float2 _4071 = (float2(float((1 - (2 * int((_5962 >> 15u) & 1u))) * int(((_5962 >> uint(7)) & 127u) << _5994)), float((1 - (2 * int((_5962 >> 14u) & 1u))) * int((_5962 & 127u) << _5994))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11730;
                    if (_3622[_9939] == 0u)
                    {
                        _11730 = -1.0f;
                    }
                    else
                    {
                        _11730 = float((_3622[_9939] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4076 = _11730 - 0.100000001490116119384765625f;
                    float2 _11731;
                    if (_5874)
                    {
                        float2 _6071 = clamp((((_9930 + (_4071 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6074 = tan(_6071.x);
                        _11731 = (float2(_6074 / cbFI_DeviceToViewDepth.z, (tan(_6071.y) * sqrt(1.0f + (_6074 * _6074))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11731 = _9930 + (_4071 * cbFI_Timestep);
                    }
                    float _4083 = cbFI_Timestep - 1.0f;
                    float2 _11732;
                    if (_5874)
                    {
                        float2 _6142 = clamp((((_9930 + (_4071 * _4083)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6145 = tan(_6142.x);
                        _11732 = (float2(_6145 / cbFI_DeviceToViewDepth.z, (tan(_6142.y) * sqrt(1.0f + (_6145 * _6145))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11732 = _9930 + (_4071 * _4083);
                    }
                    bool _6178 = all(bool2(_11731.x > 0.0f.xx.x, _11731.y > 0.0f.xx.y));
                    bool _6184;
                    if (_6178)
                    {
                        _6184 = all(bool2(_11731.x < 1.0f.xx.x, _11731.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6184 = _6178;
                    }
                    float _11735;
                    if (_6184)
                    {
                        uint _6191_dummy_parameter;
                        _11735 = max((_4076 - (log((r_depth_tm1.Load(int3(int2(floor(_11731 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6191_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11735 = 0.0f;
                    }
                    bool _6221 = all(bool2(_11732.x > 0.0f.xx.x, _11732.y > 0.0f.xx.y));
                    bool _6227;
                    if (_6221)
                    {
                        _6227 = all(bool2(_11732.x < 1.0f.xx.x, _11732.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6227 = _6221;
                    }
                    float _11736;
                    if (_6227)
                    {
                        uint _6234_dummy_parameter;
                        _11736 = _11735 + max((_4076 - (log((r_depth_tp1.Load(int3(int2(floor(_11732 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6234_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11736 = _11735;
                    }
                    float _11777;
                    int2 _11781;
                    float2 _11792;
                    int2 _11803;
                    float2 _11836;
                    float _11883;
                    if (_11736 == 0.0f)
                    {
                        bool _4118 = _4076 > _9940;
                        bool2 _11891 = _4118.xx;
                        _11883 = _11744;
                        _11836 = float2(_11891.x ? _4071.x : _9950.x, _11891.y ? _4071.y : _9950.y);
                        _11803 = int2(_11891.x ? _4065.x : _9944.x, _11891.y ? _4065.y : _9944.y);
                        _11792 = _9942;
                        _11781 = _9941;
                        _11777 = _4118 ? _4076 : _9940;
                    }
                    else
                    {
                        bool _4127 = _11736 < _11744;
                        bool2 _11887 = _4127.xx;
                        _11883 = _4127 ? _11736 : _11744;
                        _11836 = _9950;
                        _11803 = _9944;
                        _11792 = float2(_11887.x ? _4071.x : _9942.x, _11887.y ? _4071.y : _9942.y);
                        _11781 = int2(_11887.x ? _4065.x : _9941.x, _11887.y ? _4065.y : _9941.y);
                        _11777 = _9940;
                    }
                    _11882 = _11883;
                    _11835 = _11836;
                    _11802 = _11803;
                    _11791 = _11792;
                    _11780 = _11781;
                    _11776 = _11777;
                }
                bool _4139 = _9940 < 0.0f;
                bool2 _11897 = _4139.xx;
                int2 _11900 = int2(_11897.x ? _9941.x : _9944.x, _11897.y ? _9941.y : _9944.y);
                _11337 = float3(1.0f, _4030, float(any(bool2(_11900.x != _3958.x, _11900.y != _3958.y))));
                _9984 = _11900;
                _9973 = _4139 ? false : true;
                _9952 = float2(_11897.x ? _9942.x : _9950.x, _11897.y ? _9942.y : _9950.y);
            }
            else
            {
                _11337 = _9731;
                _9984 = _3958;
                _9973 = false;
                _9952 = _5852;
            }
            _11336 = _11337;
            _9983 = _9984;
            _9972 = _9973;
            _9951 = _9952;
        }
        else
        {
            _11336 = 0.0f.xxx;
            _9983 = _3958;
            _9972 = false;
            _9951 = _5852;
        }
        float2 _9953;
        if (_5874)
        {
            float2 _6299 = clamp((((_9930 + (_9951 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6302 = tan(_6299.x);
            _9953 = (float2(_6302 / cbFI_DeviceToViewDepth.z, (tan(_6299.y) * sqrt(1.0f + (_6302 * _6302))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9953 = _9930 + (_9951 * cbFI_Timestep);
        }
        float _4162 = cbFI_Timestep - 1.0f;
        float2 _9955;
        if (_5874)
        {
            float2 _6370 = clamp((((_9930 + (_9951 * _4162)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6373 = tan(_6370.x);
            _9955 = (float2(_6373 / cbFI_DeviceToViewDepth.z, (tan(_6370.y) * sqrt(1.0f + (_6373 * _6373))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9955 = _9930 + (_9951 * _4162);
        }
        float _4167 = -cbFI_Timestep;
        float2 _9956;
        if (_5874)
        {
            float2 _6441 = clamp((((_9930 + (_5846 * _4167)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6444 = tan(_6441.x);
            _9956 = (float2(_6444 / cbFI_DeviceToViewDepth.z, (tan(_6441.y) * sqrt(1.0f + (_6444 * _6444))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9956 = _9930 + (_5846 * _4167);
        }
        float _4172 = 1.0f - cbFI_Timestep;
        float2 _9957;
        if (_5874)
        {
            float2 _6512 = clamp((((_9930 + (_5846 * _4172)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6515 = tan(_6512.x);
            _9957 = (float2(_6515 / cbFI_DeviceToViewDepth.z, (tan(_6512.y) * sqrt(1.0f + (_6515 * _6515))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9957 = _9930 + (_5846 * _4172);
        }
        float4 _6550 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9953, 0.0f);
        float3 _6551 = _6550.xyz;
        float4 _6558 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9955, 0.0f);
        float3 _6559 = _6558.xyz;
        float4 _6566 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9956, 0.0f);
        float3 _6567 = _6566.xyz;
        float4 _6574 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9957, 0.0f);
        float3 _6575 = _6574.xyz;
        float4 _6589 = exp(_5840 - max(max(max(_5840.x, _5840.y), _5840.z), _5840.w).xxxx);
        float4 _6596 = _6589 / (dot(_6589, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4191 = _3984 && (!_9972);
        bool _4200;
        if (_4191)
        {
            _4200 = (_6596.z + _6596.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4200 = _4191;
        }
        bool _4211;
        if (_4200)
        {
            _4211 = length((_9956 - _9953) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4211 = _4200;
        }
        bool _9996;
        if (_4211)
        {
            uint4 _6615 = r_warped_motion_qdata_tp1.Load(int3(_9983, 0));
            uint _6616 = _6615.x;
            bool _9999;
            if (_6616 != 0u)
            {
                float _9985;
                if (_6616 == 0u)
                {
                    _9985 = -1.0f;
                }
                else
                {
                    _9985 = float((_6616 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4221 = _9985 - 0.12000000476837158203125f;
                bool _6635 = all(bool2(_9956.x > 0.0f.xx.x, _9956.y > 0.0f.xx.y));
                bool _6641;
                if (_6635)
                {
                    _6641 = all(bool2(_9956.x < 1.0f.xx.x, _9956.y < 1.0f.xx.y));
                }
                else
                {
                    _6641 = _6635;
                }
                bool _4231;
                if (_6641)
                {
                    uint _6648_dummy_parameter;
                    _4231 = (log((r_depth_tm1.Load(int3(int2(floor(_9956 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6648_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4221;
                }
                else
                {
                    _4231 = _6641;
                }
                bool _4245;
                if (!_4231)
                {
                    bool _6678 = all(bool2(_9957.x > 0.0f.xx.x, _9957.y > 0.0f.xx.y));
                    bool _6684;
                    if (_6678)
                    {
                        _6684 = all(bool2(_9957.x < 1.0f.xx.x, _9957.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6684 = _6678;
                    }
                    bool _4243;
                    if (_6684)
                    {
                        uint _6691_dummy_parameter;
                        _4243 = (log((r_depth_tp1.Load(int3(int2(floor(_9957 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6691_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4221;
                    }
                    else
                    {
                        _4243 = _6684;
                    }
                    _4245 = _4243;
                }
                else
                {
                    _4245 = _4231;
                }
                _9999 = _4245;
            }
            else
            {
                _9999 = false;
            }
            _9996 = _9999;
        }
        else
        {
            _9996 = false;
        }
        bool _4250 = _9972 || _9996;
        bool _4255;
        if (_4250)
        {
            bool _6721 = all(bool2(_9953.x > 0.0f.xx.x, _9953.y > 0.0f.xx.y));
            bool _6727;
            if (_6721)
            {
                _6727 = all(bool2(_9953.x < 1.0f.xx.x, _9953.y < 1.0f.xx.y));
            }
            else
            {
                _6727 = _6721;
            }
            _4255 = _6727;
        }
        else
        {
            _4255 = _4250;
        }
        bool _4260;
        if (_4255)
        {
            bool _6732 = all(bool2(_9955.x > 0.0f.xx.x, _9955.y > 0.0f.xx.y));
            bool _6738;
            if (_6732)
            {
                _6738 = all(bool2(_9955.x < 1.0f.xx.x, _9955.y < 1.0f.xx.y));
            }
            else
            {
                _6738 = _6732;
            }
            _4260 = _6738;
        }
        else
        {
            _4260 = _4255;
        }
        float4 _10093;
        if (_4260)
        {
            float _4263 = _6596.x;
            float _4265 = _6596.y;
            float _4266 = _4263 + _4265;
            float _4271 = _6596.z + _6596.w;
            float _10014;
            if (_4266 > 0.001000000047497451305389404296875f)
            {
                _10014 = _4263 / _4266;
            }
            else
            {
                _10014 = _4172;
            }
            _10093 = float4(_4263 + (_4271 * _10014), _4265 + (_4271 * (1.0f - _10014)), 0.0f, 0.0f);
        }
        else
        {
            _10093 = _6596;
        }
        bool _6766 = (cbFI_pad0 & 1024u) != 0u;
        bool _6742 = !_6766;
        bool _6743 = !_6742;
        bool _6760;
        if (_6743)
        {
            _6760 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9983.y * cbFI_MvDepthLaneSize.x) + _9983.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6760 = _6742;
        }
        bool _6792;
        if (_6743)
        {
            _6792 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3963.y * cbFI_FlowLaneSize.x) + _3963.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6792 = _6742;
        }
        float _4306 = float(_6792);
        bool _10106;
        float4 _10191;
        float3 _11151;
        if (_6766)
        {
            bool _4316;
            if (_6760)
            {
                _4316 = all(bool2(_9953.x > 0.0f.xx.x, _9953.y > 0.0f.xx.y));
            }
            else
            {
                _4316 = _6760;
            }
            bool _4322;
            if (_4316)
            {
                _4322 = all(bool2(_9953.x < 1.0f.xx.x, _9953.y < 1.0f.xx.y));
            }
            else
            {
                _4322 = _4316;
            }
            bool _4329;
            if (_6760)
            {
                _4329 = all(bool2(_9955.x > 0.0f.xx.x, _9955.y > 0.0f.xx.y));
            }
            else
            {
                _4329 = _6760;
            }
            bool _4335;
            if (_4329)
            {
                _4335 = all(bool2(_9955.x < 1.0f.xx.x, _9955.y < 1.0f.xx.y));
            }
            else
            {
                _4335 = _4329;
            }
            bool _4342;
            if (_6792)
            {
                _4342 = all(bool2(_9956.x > 0.0f.xx.x, _9956.y > 0.0f.xx.y));
            }
            else
            {
                _4342 = _6792;
            }
            bool _4348;
            if (_4342)
            {
                _4348 = all(bool2(_9956.x < 1.0f.xx.x, _9956.y < 1.0f.xx.y));
            }
            else
            {
                _4348 = _4342;
            }
            bool _4355;
            if (_6792)
            {
                _4355 = all(bool2(_9957.x > 0.0f.xx.x, _9957.y > 0.0f.xx.y));
            }
            else
            {
                _4355 = _6792;
            }
            bool _4361;
            if (_4355)
            {
                _4361 = all(bool2(_9957.x < 1.0f.xx.x, _9957.y < 1.0f.xx.y));
            }
            else
            {
                _4361 = _4355;
            }
            bool _4363 = !_6760;
            if (_4363)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6834;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6834);
                }
            }
            bool _4368 = !_6792;
            if (_4368)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6844;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6844);
                }
            }
            if (_6760 && _4368)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6854;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6854);
                }
            }
            if (_4363 && _6792)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6864;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6864);
                }
            }
            float _4387 = float(_4322);
            float _4389 = float(_4335);
            bool _4392 = _4348 && _4361;
            float _10048;
            if (_4392)
            {
                _10048 = 1.0f;
            }
            else
            {
                _10048 = (_4348 || _4361) ? 0.5f : 0.0f;
            }
            bool _10053;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4322)) && (!_4335))
            {
                bool _4422;
                if (_4392)
                {
                    float _10051;
                    do
                    {
                        bool _6948 = all(bool2(_9956.x > 0.0f.xx.x, _9956.y > 0.0f.xx.y));
                        bool _6954;
                        if (_6948)
                        {
                            _6954 = all(bool2(_9956.x < 1.0f.xx.x, _9956.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6954 = _6948;
                        }
                        bool _6885 = !_6954;
                        bool _6892;
                        if (!_6885)
                        {
                            bool _6959 = all(bool2(_9957.x > 0.0f.xx.x, _9957.y > 0.0f.xx.y));
                            bool _6965;
                            if (_6959)
                            {
                                _6965 = all(bool2(_9957.x < 1.0f.xx.x, _9957.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6965 = _6959;
                            }
                            _6892 = !_6965;
                        }
                        else
                        {
                            _6892 = _6885;
                        }
                        if (_6892)
                        {
                            _10051 = 0.0f;
                            break;
                        }
                        uint _6972_dummy_parameter;
                        uint _6988_dummy_parameter;
                        float4 _6913 = mul(float4((float2(_9956.x, 1.0f - _9956.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9956 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6972_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6915 = _6913.w;
                        if (abs(_6915) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10051 = 0.0f;
                            break;
                        }
                        float _6926 = abs(cbFI_DeviceToViewDepth.y / ((_6913.z / _6915) - cbFI_DeviceToViewDepth.x));
                        float _6929 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9957 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6988_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10051 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6926 - _6929) / max(max(_6926, _6929), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4422 = _10051 >= 0.5f;
                }
                else
                {
                    _4422 = _4392;
                }
                bool _4430;
                if (_4422)
                {
                    _4430 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4430 = _4422;
                }
                bool _10054;
                if (_4430)
                {
                    uint _7038_dummy_parameter;
                    float2 _10052;
                    do
                    {
                        float _7064 = 1.0f - _9956.y;
                        float4 _7075 = mul(float4((float2(_9956.x, _7064) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9956 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7038_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7077 = _7075.w;
                        if (!(_7077 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10052 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7090 = ((_7075.xy / _7077.xx) + 1.0f.xx) * 0.5f;
                        _10052 = float2(_7090.x - _9956.x, _7064 - _7090.y);
                        break;
                    } while(false);
                    float2 _4443 = float2(cbFI_DisplaySize);
                    _10054 = length(((_9956 + _10052) - _9957) * _4443) <= ((0.100000001490116119384765625f * length(_10052 * _4443)) + 8.0f);
                }
                else
                {
                    _10054 = _4422;
                }
                _10053 = _10054;
            }
            else
            {
                _10053 = true;
            }
            bool _4457 = !_10053;
            bool _11901 = _4457 ? false : _4361;
            bool _11902 = _4457 ? false : _4348;
            bool _10107;
            float4 _10192;
            if (!(((_4322 && _4335) && _11902) && _11901))
            {
                float4 _4479 = _10093 * float4(_4387, _4389, float(_11902), float(_11901));
                float _4481 = dot(_4479, 1.0f.xxxx);
                bool _4484 = !(_4481 > 0.0f);
                float4 _10193;
                if (!_4484)
                {
                    _10193 = _4479 / _4481.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7112;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7112);
                    }
                    _10193 = 0.0f.xxxx;
                }
                _10192 = _10193;
                _10107 = _4484;
            }
            else
            {
                _10192 = _10093;
                _10107 = false;
            }
            _11151 = float3(_4387, _4389, _10048);
            _10191 = _10192;
            _10106 = _10107;
        }
        else
        {
            _11151 = float3(float(_6760), _4306, 0.0f);
            _10191 = _10093;
            _10106 = false;
        }
        bool _4502 = !_10106;
        float4 _10292;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4502) && _6760)
        {
            float _10188;
            do
            {
                uint4 _7252 = r_warped_motion_qdata_tp1.Load(int3(_9983, 0));
                uint _7253 = _7252.x;
                if (_7253 != 0u)
                {
                    float _10187;
                    if (_7253 == 0u)
                    {
                        _10187 = -1.0f;
                    }
                    else
                    {
                        _10187 = float((_7253 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10188 = _10187;
                    break;
                }
                int _10170;
                uint _10171;
                _10171 = _7253;
                _10170 = -1;
                uint _10186;
                for (; _10170 <= 1; _10171 = _10186, _10170++)
                {
                    _10186 = _10171;
                    for (int _10184 = -1; _10184 <= 1; )
                    {
                        _10186 = max(_10186, r_warped_motion_qdata_tp1.Load(int3(clamp(_9983 + int2(_10184, _10170), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10184++;
                        continue;
                    }
                }
                if (_10171 != 0u)
                {
                    float _10183;
                    if (_10171 == 0u)
                    {
                        _10183 = -1.0f;
                    }
                    else
                    {
                        _10183 = float((_10171 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10188 = _10183;
                    break;
                }
                uint _10173;
                _10173 = 4294967295u;
                uint _11872;
                for (int _10172 = 0; _10172 < 8; _10173 = _11872, _10172++)
                {
                    int _10176 = 0;
                    for (;;)
                    {
                        if (_10176 < 5)
                        {
                            int2 _7203 = _9983 + (_1085[_10172] * _1094[_10176].xx);
                            bool _7206 = any(bool2(_7203.x < int2(0, 0).x, _7203.y < int2(0, 0).y));
                            bool _7214;
                            if (!_7206)
                            {
                                _7214 = any(bool2(_7203.x >= cbFI_MvDepthLaneSize.x, _7203.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7214 = _7206;
                            }
                            if (_7214)
                            {
                                _11872 = _10173;
                                break;
                            }
                            uint4 _7292 = r_warped_motion_qdata_tp1.Load(int3(_7203, 0));
                            uint _7293 = _7292.x;
                            if (_7293 != 0u)
                            {
                                _11872 = min(_10173, _7293);
                                break;
                            }
                            _10176++;
                            continue;
                        }
                        else
                        {
                            _11872 = _10173;
                            break;
                        }
                    }
                }
                float _10175;
                if (_10173 == 4294967295u)
                {
                    _10175 = -1.0f;
                }
                else
                {
                    float _10174;
                    if (_10173 == 0u)
                    {
                        _10174 = -1.0f;
                    }
                    else
                    {
                        _10174 = float((_10173 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10175 = _10174;
                }
                _10188 = _10175;
                break;
            } while(false);
            float _4513 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4517 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4523;
            if (_4517)
            {
                _4523 = _10191.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4523 = _4517;
            }
            bool _4528;
            if (_4523)
            {
                bool _7312 = all(bool2(_9955.x > 0.0f.xx.x, _9955.y > 0.0f.xx.y));
                bool _7318;
                if (_7312)
                {
                    _7318 = all(bool2(_9955.x < 1.0f.xx.x, _9955.y < 1.0f.xx.y));
                }
                else
                {
                    _7318 = _7312;
                }
                _4528 = _7318;
            }
            else
            {
                _4528 = _4523;
            }
            float4 _10234;
            if (_4528)
            {
                float _10209;
                if (_10188 >= 0.0f)
                {
                    _10209 = _10188 - _4513;
                }
                else
                {
                    float _10205;
                    _10205 = 2.0f;
                    float _7375;
                    for (int _10204 = 0; _10204 < 24; _10205 = _7375, _10204++)
                    {
                        float _7339 = float(_10204 & 7) * 0.785398185253143310546875f;
                        int _7341 = _10204 >> 3;
                        int _10206;
                        if (_7341 == 0)
                        {
                            _10206 = 16;
                        }
                        else
                        {
                            _10206 = (_7341 == 1) ? 48 : 96;
                        }
                        uint _7407_dummy_parameter;
                        _7375 = min(_10205, log((r_depth_tp1.Load(int3(int2(floor(clamp(_9955 + ((cbFI_MvDepthLaneSizeRcp * float(_10206)) * float2(cos(_7339), sin(_7339))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7407_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10209 = _10205;
                }
                uint _7439_dummy_parameter;
                float4 _10235;
                if (r_depth_tp1.Load(int3(int2(floor(_9955 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7439_dummy_parameter))))), 0)).x > ((exp((_10209 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10235 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10235 = 1.0f.xxxx;
                }
                _10234 = _10235;
            }
            else
            {
                _10234 = 1.0f.xxxx;
            }
            bool _4555 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4561;
            if (_4555)
            {
                _4561 = _10191.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4561 = _4555;
            }
            bool _4566;
            if (_4561)
            {
                bool _7463 = all(bool2(_9953.x > 0.0f.xx.x, _9953.y > 0.0f.xx.y));
                bool _7469;
                if (_7463)
                {
                    _7469 = all(bool2(_9953.x < 1.0f.xx.x, _9953.y < 1.0f.xx.y));
                }
                else
                {
                    _7469 = _7463;
                }
                _4566 = _7469;
            }
            else
            {
                _4566 = _4561;
            }
            float4 _10238;
            if (_4566)
            {
                float _10229;
                if (_10188 >= 0.0f)
                {
                    _10229 = _10188 - _4513;
                }
                else
                {
                    float _10225;
                    _10225 = 2.0f;
                    float _7526;
                    for (int _10224 = 0; _10224 < 24; _10225 = _7526, _10224++)
                    {
                        float _7490 = float(_10224 & 7) * 0.785398185253143310546875f;
                        int _7492 = _10224 >> 3;
                        int _10226;
                        if (_7492 == 0)
                        {
                            _10226 = 16;
                        }
                        else
                        {
                            _10226 = (_7492 == 1) ? 48 : 96;
                        }
                        uint _7542_dummy_parameter;
                        _7526 = min(_10225, log((r_depth_tm1.Load(int3(int2(floor(clamp(_9953 + ((cbFI_MvDepthLaneSizeRcp * float(_10226)) * float2(cos(_7490), sin(_7490))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7542_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10229 = _10225;
                }
                uint _7590_dummy_parameter;
                float4 _10239;
                if (r_depth_tm1.Load(int3(int2(floor(_9953 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7590_dummy_parameter))))), 0)).x > ((exp((_10229 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9799 = _10234;
                    _9799.x = 0.0f;
                    _10239 = _9799;
                }
                else
                {
                    _10239 = _10234;
                }
                _10238 = _10239;
            }
            else
            {
                _10238 = _10234;
            }
            float4 _10293;
            if (any(bool4(_10238.x < 1.0f.xxxx.x, _10238.y < 1.0f.xxxx.y, _10238.z < 1.0f.xxxx.z, _10238.w < 1.0f.xxxx.w)))
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7618;
                    rw_nfru_diagnostics.InterlockedAdd(240, 1u, _7618);
                }
                float4 _4597 = _10191 * _10238;
                float _4599 = dot(_4597, 1.0f.xxxx);
                float4 _10294;
                if (_4599 > 0.0f)
                {
                    _10294 = _4597 / _4599.xxxx;
                }
                else
                {
                    bool _4610 = _10238.y == 0.0f;
                    bool _4616;
                    if (_4610)
                    {
                        _4616 = _10238.x > 0.0f;
                    }
                    else
                    {
                        _4616 = _4610;
                    }
                    bool _4621;
                    if (_4616)
                    {
                        bool _7624 = all(bool2(_9953.x > 0.0f.xx.x, _9953.y > 0.0f.xx.y));
                        bool _7630;
                        if (_7624)
                        {
                            _7630 = all(bool2(_9953.x < 1.0f.xx.x, _9953.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7630 = _7624;
                        }
                        _4621 = _7630;
                    }
                    else
                    {
                        _4621 = _4616;
                    }
                    float4 _10295;
                    if (_4621)
                    {
                        _10295 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4626 = _10238.x == 0.0f;
                        bool _4632;
                        if (_4626)
                        {
                            _4632 = _10238.y > 0.0f;
                        }
                        else
                        {
                            _4632 = _4626;
                        }
                        bool _4637;
                        if (_4632)
                        {
                            bool _7635 = all(bool2(_9955.x > 0.0f.xx.x, _9955.y > 0.0f.xx.y));
                            bool _7641;
                            if (_7635)
                            {
                                _7641 = all(bool2(_9955.x < 1.0f.xx.x, _9955.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7641 = _7635;
                            }
                            _4637 = _7641;
                        }
                        else
                        {
                            _4637 = _4632;
                        }
                        bool4 _11903 = _4637.xxxx;
                        _10295 = float4(_11903.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10191.x, _11903.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10191.y, _11903.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10191.z, _11903.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10191.w);
                    }
                    _10294 = _10295;
                }
                _10293 = _10294;
            }
            else
            {
                _10293 = _10191;
            }
            _10292 = _10293;
        }
        else
        {
            _10292 = _10191;
        }
        float4 _10838;
        bool _10858;
        float3 _10972;
        if (((cbFI_pad0 & 32768u) != 0u) && _4502)
        {
            bool _4654 = _10292.x > 0.00999999977648258209228515625f;
            bool _4657 = _10292.y > 0.00999999977648258209228515625f;
            bool _4666 = (_10292.z + _10292.w) > 0.0199999995529651641845703125f;
            bool _4672;
            if (_4666)
            {
                bool _7646 = all(bool2(_9956.x > 0.0f.xx.x, _9956.y > 0.0f.xx.y));
                bool _7652;
                if (_7646)
                {
                    _7652 = all(bool2(_9956.x < 1.0f.xx.x, _9956.y < 1.0f.xx.y));
                }
                else
                {
                    _7652 = _7646;
                }
                _4672 = _7652;
            }
            else
            {
                _4672 = _4666;
            }
            bool _4677;
            if (_4672)
            {
                bool _7657 = all(bool2(_9957.x > 0.0f.xx.x, _9957.y > 0.0f.xx.y));
                bool _7663;
                if (_7657)
                {
                    _7663 = all(bool2(_9957.x < 1.0f.xx.x, _9957.y < 1.0f.xx.y));
                }
                else
                {
                    _7663 = _7657;
                }
                _4677 = _7663;
            }
            else
            {
                _4677 = _4672;
            }
            bool _4684;
            if (_4677)
            {
                float _10303;
                do
                {
                    bool _7746 = all(bool2(_9956.x > 0.0f.xx.x, _9956.y > 0.0f.xx.y));
                    bool _7752;
                    if (_7746)
                    {
                        _7752 = all(bool2(_9956.x < 1.0f.xx.x, _9956.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7752 = _7746;
                    }
                    bool _7683 = !_7752;
                    bool _7690;
                    if (!_7683)
                    {
                        bool _7757 = all(bool2(_9957.x > 0.0f.xx.x, _9957.y > 0.0f.xx.y));
                        bool _7763;
                        if (_7757)
                        {
                            _7763 = all(bool2(_9957.x < 1.0f.xx.x, _9957.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7763 = _7757;
                        }
                        _7690 = !_7763;
                    }
                    else
                    {
                        _7690 = _7683;
                    }
                    if (_7690)
                    {
                        _10303 = 0.0f;
                        break;
                    }
                    uint _7770_dummy_parameter;
                    uint _7786_dummy_parameter;
                    float4 _7711 = mul(float4((float2(_9956.x, 1.0f - _9956.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9956 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7770_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7713 = _7711.w;
                    if (abs(_7713) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10303 = 0.0f;
                        break;
                    }
                    float _7724 = abs(cbFI_DeviceToViewDepth.y / ((_7711.z / _7713) - cbFI_DeviceToViewDepth.x));
                    float _7727 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9957 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7786_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10303 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7724 - _7727) / max(max(_7724, _7727), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4684 = _10303 < 0.5f;
            }
            else
            {
                _4684 = _4677;
            }
            float4 _10318;
            if (_4684)
            {
                uint _7836_dummy_parameter;
                uint _7867_dummy_parameter;
                float4 _10319;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9956 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7836_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9957 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7867_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10319 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10319 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10318 = _10319;
            }
            else
            {
                _10318 = 1.0f.xxxx;
            }
            bool _4708;
            if (_6760)
            {
                bool _7896 = all(bool2(_9953.x > 0.0f.xx.x, _9953.y > 0.0f.xx.y));
                bool _7902;
                if (_7896)
                {
                    _7902 = all(bool2(_9953.x < 1.0f.xx.x, _9953.y < 1.0f.xx.y));
                }
                else
                {
                    _7902 = _7896;
                }
                _4708 = _7902;
            }
            else
            {
                _4708 = _6760;
            }
            bool _4714;
            if (_6760)
            {
                bool _7907 = all(bool2(_9955.x > 0.0f.xx.x, _9955.y > 0.0f.xx.y));
                bool _7913;
                if (_7907)
                {
                    _7913 = all(bool2(_9955.x < 1.0f.xx.x, _9955.y < 1.0f.xx.y));
                }
                else
                {
                    _7913 = _7907;
                }
                _4714 = _7913;
            }
            else
            {
                _4714 = _6760;
            }
            bool _4720;
            if (_6792)
            {
                bool _7918 = all(bool2(_9956.x > 0.0f.xx.x, _9956.y > 0.0f.xx.y));
                bool _7924;
                if (_7918)
                {
                    _7924 = all(bool2(_9956.x < 1.0f.xx.x, _9956.y < 1.0f.xx.y));
                }
                else
                {
                    _7924 = _7918;
                }
                _4720 = _7924;
            }
            else
            {
                _4720 = _6792;
            }
            bool _4726;
            if (_6792)
            {
                bool _7929 = all(bool2(_9957.x > 0.0f.xx.x, _9957.y > 0.0f.xx.y));
                bool _7935;
                if (_7929)
                {
                    _7935 = all(bool2(_9957.x < 1.0f.xx.x, _9957.y < 1.0f.xx.y));
                }
                else
                {
                    _7935 = _7929;
                }
                _4726 = _7935;
            }
            else
            {
                _4726 = _6792;
            }
            bool _4729 = _4720 != _4726;
            bool _4735;
            if (_4729)
            {
                _4735 = _4708 || _4714;
            }
            else
            {
                _4735 = _4729;
            }
            float4 _10407;
            if (_4735)
            {
                float4 _9826 = _10318;
                _9826.z = 0.0f;
                _9826.w = 0.0f;
                _10407 = _9826;
            }
            else
            {
                _10407 = _10318;
            }
            bool _4742 = _4708 && _4654;
            bool _4745 = _4714 && _4657;
            float4 _10512;
            float3 _11050;
            if (_4742 || _4745)
            {
                float _10402;
                do
                {
                    uint4 _8074 = r_warped_motion_qdata_tp1.Load(int3(_9983, 0));
                    uint _8075 = _8074.x;
                    if (_8075 != 0u)
                    {
                        float _10401;
                        if (_8075 == 0u)
                        {
                            _10401 = -1.0f;
                        }
                        else
                        {
                            _10401 = float((_8075 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10402 = _10401;
                        break;
                    }
                    int _10384;
                    uint _10385;
                    _10385 = _8075;
                    _10384 = -1;
                    uint _10400;
                    for (; _10384 <= 1; _10385 = _10400, _10384++)
                    {
                        _10400 = _10385;
                        for (int _10398 = -1; _10398 <= 1; )
                        {
                            _10400 = max(_10400, r_warped_motion_qdata_tp1.Load(int3(clamp(_9983 + int2(_10398, _10384), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10398++;
                            continue;
                        }
                    }
                    if (_10385 != 0u)
                    {
                        float _10397;
                        if (_10385 == 0u)
                        {
                            _10397 = -1.0f;
                        }
                        else
                        {
                            _10397 = float((_10385 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10402 = _10397;
                        break;
                    }
                    uint _10387;
                    _10387 = 4294967295u;
                    uint _11873;
                    for (int _10386 = 0; _10386 < 8; _10387 = _11873, _10386++)
                    {
                        int _10390 = 0;
                        for (;;)
                        {
                            if (_10390 < 5)
                            {
                                int2 _8025 = _9983 + (_1085[_10386] * _1094[_10390].xx);
                                bool _8028 = any(bool2(_8025.x < int2(0, 0).x, _8025.y < int2(0, 0).y));
                                bool _8036;
                                if (!_8028)
                                {
                                    _8036 = any(bool2(_8025.x >= cbFI_MvDepthLaneSize.x, _8025.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8036 = _8028;
                                }
                                if (_8036)
                                {
                                    _11873 = _10387;
                                    break;
                                }
                                uint4 _8114 = r_warped_motion_qdata_tp1.Load(int3(_8025, 0));
                                uint _8115 = _8114.x;
                                if (_8115 != 0u)
                                {
                                    _11873 = min(_10387, _8115);
                                    break;
                                }
                                _10390++;
                                continue;
                            }
                            else
                            {
                                _11873 = _10387;
                                break;
                            }
                        }
                    }
                    float _10389;
                    if (_10387 == 4294967295u)
                    {
                        _10389 = -1.0f;
                    }
                    else
                    {
                        float _10388;
                        if (_10387 == 0u)
                        {
                            _10388 = -1.0f;
                        }
                        else
                        {
                            _10388 = float((_10387 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10389 = _10388;
                    }
                    _10402 = _10389;
                    break;
                } while(false);
                bool _4753 = _10402 < 0.0f;
                float _10403;
                if (_4753)
                {
                    _10403 = 0.0f;
                }
                else
                {
                    _10403 = _10402 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8136_dummy_parameter;
                uint _8168_dummy_parameter;
                float4 _10440;
                if ((_4753 && _4742) && _4745)
                {
                    uint _8200_dummy_parameter;
                    float _8224 = log((r_depth_tm1.Load(int3(int2(floor(_9953 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8200_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8232_dummy_parameter;
                    float _8256 = log((r_depth_tp1.Load(int3(int2(floor(_9955 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8232_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10441;
                    if (_8224 > (_8256 + 0.07999999821186065673828125f))
                    {
                        float4 _9830 = _10407;
                        _9830.x = 0.0f;
                        _10441 = _9830;
                    }
                    else
                    {
                        float4 _10442;
                        if (_8256 > (_8224 + 0.07999999821186065673828125f))
                        {
                            float4 _9832 = _10407;
                            _9832.y = 0.0f;
                            _10442 = _9832;
                        }
                        else
                        {
                            _10442 = _10407;
                        }
                        _10441 = _10442;
                    }
                    _10440 = _10441;
                }
                else
                {
                    _10440 = _10407;
                }
                float _4805 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4807 = _10402 >= 0.0f;
                float _10423;
                if (_4807)
                {
                    _10423 = _10402 - _4805;
                }
                else
                {
                    float _10419;
                    if (_4742)
                    {
                        float _10418;
                        _10418 = 2.0f;
                        float _8314;
                        for (int _10417 = 0; _10417 < 24; _10418 = _8314, _10417++)
                        {
                            float _8278 = float(_10417 & 7) * 0.785398185253143310546875f;
                            int _8280 = _10417 >> 3;
                            int _10420;
                            if (_8280 == 0)
                            {
                                _10420 = 16;
                            }
                            else
                            {
                                _10420 = (_8280 == 1) ? 48 : 96;
                            }
                            uint _8330_dummy_parameter;
                            _8314 = min(_10418, log((r_depth_tm1.Load(int3(int2(floor(clamp(_9953 + ((cbFI_MvDepthLaneSizeRcp * float(_10420)) * float2(cos(_8278), sin(_8278))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8330_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10419 = _10418;
                    }
                    else
                    {
                        _10419 = 0.0f;
                    }
                    _10423 = _10419;
                }
                float _10430;
                if (_4807)
                {
                    _10430 = _10402 - _4805;
                }
                else
                {
                    float _10426;
                    if (_4745)
                    {
                        float _10425;
                        _10425 = 2.0f;
                        float _8428;
                        for (int _10424 = 0; _10424 < 24; _10425 = _8428, _10424++)
                        {
                            float _8392 = float(_10424 & 7) * 0.785398185253143310546875f;
                            int _8394 = _10424 >> 3;
                            int _10427;
                            if (_8394 == 0)
                            {
                                _10427 = 16;
                            }
                            else
                            {
                                _10427 = (_8394 == 1) ? 48 : 96;
                            }
                            uint _8460_dummy_parameter;
                            _8428 = min(_10425, log((r_depth_tp1.Load(int3(int2(floor(clamp(_9955 + ((cbFI_MvDepthLaneSizeRcp * float(_10427)) * float2(cos(_8392), sin(_8392))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8460_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10426 = _10425;
                    }
                    else
                    {
                        _10426 = 0.0f;
                    }
                    _10430 = _10426;
                }
                float _10431;
                if (_4742)
                {
                    uint _8492_dummy_parameter;
                    _10431 = r_depth_tm1.Load(int3(int2(floor(_9953 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8492_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10431 = 0.0f;
                }
                float _10432;
                if (_4745)
                {
                    uint _8511_dummy_parameter;
                    _10432 = r_depth_tp1.Load(int3(int2(floor(_9955 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8511_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10432 = 0.0f;
                }
                bool _4862;
                if (_4742)
                {
                    _4862 = _10431 > ((exp((_10423 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4862 = _4742;
                }
                float4 _10448;
                if (_4862)
                {
                    float4 _9834 = _10440;
                    _9834.x = 0.0f;
                    _10448 = _9834;
                }
                else
                {
                    _10448 = _10440;
                }
                bool _4874;
                if (_4745)
                {
                    _4874 = _10432 > ((exp((_10430 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4874 = _4745;
                }
                float4 _10450;
                if (_4874)
                {
                    float4 _9836 = _10448;
                    _9836.y = 0.0f;
                    _10450 = _9836;
                }
                else
                {
                    _10450 = _10448;
                }
                float4 _10513;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4807)
                {
                    bool _4894;
                    if (_4742)
                    {
                        _4894 = _10431 < ((exp((_10423 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4894 = _4742;
                    }
                    float4 _10452;
                    if (_4894)
                    {
                        float4 _9838 = _10450;
                        _9838.x = 0.0f;
                        _10452 = _9838;
                    }
                    else
                    {
                        _10452 = _10450;
                    }
                    bool _4906;
                    if (_4745)
                    {
                        _4906 = _10432 < ((exp((_10430 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4906 = _4745;
                    }
                    float4 _10514;
                    if (_4906)
                    {
                        float4 _9840 = _10452;
                        _9840.y = 0.0f;
                        _10514 = _9840;
                    }
                    else
                    {
                        _10514 = _10452;
                    }
                    _10513 = _10514;
                }
                else
                {
                    _10513 = _10450;
                }
                _11050 = float3(_10403, log((r_depth_tm1.Load(int3(int2(floor(_9953 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8136_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_9955 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8168_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _10512 = _10513;
            }
            else
            {
                _11050 = float3(0.0f, 0.0f, 0.5f);
                _10512 = _10407;
            }
            bool _4917 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4666;
            bool _4923;
            if (_4917)
            {
                _4923 = _4720 || _4726;
            }
            else
            {
                _4923 = _4917;
            }
            float4 _10535;
            if (_4923)
            {
                float _10507;
                do
                {
                    uint4 _8690 = r_warped_motion_qdata_tp1.Load(int3(_9983, 0));
                    uint _8691 = _8690.x;
                    if (_8691 != 0u)
                    {
                        float _10506;
                        if (_8691 == 0u)
                        {
                            _10506 = -1.0f;
                        }
                        else
                        {
                            _10506 = float((_8691 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10507 = _10506;
                        break;
                    }
                    int _10489;
                    uint _10490;
                    _10490 = _8691;
                    _10489 = -1;
                    uint _10505;
                    for (; _10489 <= 1; _10490 = _10505, _10489++)
                    {
                        _10505 = _10490;
                        for (int _10503 = -1; _10503 <= 1; )
                        {
                            _10505 = max(_10505, r_warped_motion_qdata_tp1.Load(int3(clamp(_9983 + int2(_10503, _10489), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10503++;
                            continue;
                        }
                    }
                    if (_10490 != 0u)
                    {
                        float _10502;
                        if (_10490 == 0u)
                        {
                            _10502 = -1.0f;
                        }
                        else
                        {
                            _10502 = float((_10490 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10507 = _10502;
                        break;
                    }
                    uint _10492;
                    _10492 = 4294967295u;
                    uint _11874;
                    for (int _10491 = 0; _10491 < 8; _10492 = _11874, _10491++)
                    {
                        int _10495 = 0;
                        for (;;)
                        {
                            if (_10495 < 5)
                            {
                                int2 _8641 = _9983 + (_1085[_10491] * _1094[_10495].xx);
                                bool _8644 = any(bool2(_8641.x < int2(0, 0).x, _8641.y < int2(0, 0).y));
                                bool _8652;
                                if (!_8644)
                                {
                                    _8652 = any(bool2(_8641.x >= cbFI_MvDepthLaneSize.x, _8641.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8652 = _8644;
                                }
                                if (_8652)
                                {
                                    _11874 = _10492;
                                    break;
                                }
                                uint4 _8730 = r_warped_motion_qdata_tp1.Load(int3(_8641, 0));
                                uint _8731 = _8730.x;
                                if (_8731 != 0u)
                                {
                                    _11874 = min(_10492, _8731);
                                    break;
                                }
                                _10495++;
                                continue;
                            }
                            else
                            {
                                _11874 = _10492;
                                break;
                            }
                        }
                    }
                    float _10494;
                    if (_10492 == 4294967295u)
                    {
                        _10494 = -1.0f;
                    }
                    else
                    {
                        float _10493;
                        if (_10492 == 0u)
                        {
                            _10493 = -1.0f;
                        }
                        else
                        {
                            _10493 = float((_10492 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10494 = _10493;
                    }
                    _10507 = _10494;
                    break;
                } while(false);
                float4 _10536;
                if (_10507 >= 0.0f)
                {
                    float _8752 = (exp((_10507 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4942;
                    if (_4720)
                    {
                        uint _8759_dummy_parameter;
                        _4942 = r_depth_tm1.Load(int3(int2(floor(_9956 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8759_dummy_parameter))))), 0)).x > _8752;
                    }
                    else
                    {
                        _4942 = _4720;
                    }
                    float4 _10525;
                    if (_4942)
                    {
                        float4 _9842 = _10512;
                        _9842.z = 0.0f;
                        _10525 = _9842;
                    }
                    else
                    {
                        _10525 = _10512;
                    }
                    bool _4954;
                    if (_4726)
                    {
                        uint _8778_dummy_parameter;
                        _4954 = r_depth_tp1.Load(int3(int2(floor(_9957 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8778_dummy_parameter))))), 0)).x > _8752;
                    }
                    else
                    {
                        _4954 = _4726;
                    }
                    float4 _10537;
                    if (_4954)
                    {
                        float4 _9844 = _10525;
                        _9844.w = 0.0f;
                        _10537 = _9844;
                    }
                    else
                    {
                        _10537 = _10525;
                    }
                    _10536 = _10537;
                }
                else
                {
                    _10536 = _10512;
                }
                _10535 = _10536;
            }
            else
            {
                _10535 = _10512;
            }
            bool _4962 = _4708 != _4714;
            bool _4969;
            if (_4962)
            {
                _4969 = _4708 ? _4654 : _4657;
            }
            else
            {
                _4969 = _4962;
            }
            bool _4976;
            if (_4969)
            {
                _4976 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _4976 = _4969;
            }
            float4 _10620;
            if (_4976)
            {
                bool2 _4981 = _4708.xx;
                float2 _4982 = float2(_4981.x ? _9953.x : _9955.x, _4981.y ? _9953.y : _9955.y);
                float _10527;
                if (_4708)
                {
                    uint _8797_dummy_parameter;
                    _10527 = r_depth_tm1.Load(int3(int2(floor(_4982 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8797_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8813_dummy_parameter;
                    _10527 = r_depth_tp1.Load(int3(int2(floor(_4982 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8813_dummy_parameter))))), 0)).x;
                }
                float4x4 _10528;
                if (_4708)
                {
                    _10528 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10528 = cbFI_MotionTP1ToTM1;
                }
                float2 _10529;
                do
                {
                    float _8840 = _4982.x;
                    float _8843 = 1.0f - _4982.y;
                    float4 _8854 = mul(float4((float2(_8840, _8843) * 2.0f) - 1.0f.xx, _10527, 1.0f), _10528);
                    float _8856 = _8854.w;
                    if (!(_8856 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10529 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8869 = ((_8854.xy / _8856.xx) + 1.0f.xx) * 0.5f;
                    _10529 = float2(_8869.x - _8840, _8843 - _8869.y);
                    break;
                } while(false);
                float2 _5012 = float2(cbFI_DisplaySize);
                float4 _10621;
                if (!(length(((_4982 + _10529) - float2(_4981.x ? _9955.x : _9953.x, _4981.y ? _9955.y : _9953.y)) * _5012) <= ((0.100000001490116119384765625f * length(_10529 * _5012)) + 8.0f)))
                {
                    float4 _10622;
                    if (_4708)
                    {
                        float4 _9854 = _10535;
                        _9854.x = 0.0f;
                        _10622 = _9854;
                    }
                    else
                    {
                        float4 _9856 = _10535;
                        _9856.y = 0.0f;
                        _10622 = _9856;
                    }
                    _10621 = _10622;
                }
                else
                {
                    _10621 = _10535;
                }
                _10620 = _10621;
            }
            else
            {
                _10620 = _10535;
            }
            float4 _5037 = _10292 * _10620;
            float _5039 = dot(_5037, 1.0f.xxxx);
            float4 _10839;
            bool _10859;
            if (_5039 > 0.0f)
            {
                _10859 = _10106;
                _10839 = _5037 / _5039.xxxx;
            }
            else
            {
                bool _5050 = any(bool4(_10620.x < 1.0f.xxxx.x, _10620.y < 1.0f.xxxx.y, _10620.z < 1.0f.xxxx.z, _10620.w < 1.0f.xxxx.w));
                if (_5050)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8891;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8891);
                    }
                }
                bool4 _11906 = _5050.xxxx;
                _10859 = _5050 ? true : _10106;
                _10839 = float4(_11906.x ? 0.0f.xxxx.x : _10292.x, _11906.y ? 0.0f.xxxx.y : _10292.y, _11906.z ? 0.0f.xxxx.z : _10292.z, _11906.w ? 0.0f.xxxx.w : _10292.w);
            }
            _10972 = _11050;
            _10858 = _10859;
            _10838 = _10839;
        }
        else
        {
            _10972 = float3(0.0f, 0.0f, 0.5f);
            _10858 = _10106;
            _10838 = _10292;
        }
        uint _5059 = (cbFI_pad0 >> 24u) & 31u;
        uint _5063 = (cbFI_pad0 >> 16u) & 255u;
        bool _5065 = _5059 != 0u;
        bool _5067 = _5063 == 12u;
        bool _5070 = _5063 == 13u;
        float4 _10855;
        if ((_5065 || _5067) || _5070)
        {
            float _10623;
            do
            {
                bool _8975 = all(bool2(_9956.x > 0.0f.xx.x, _9956.y > 0.0f.xx.y));
                bool _8981;
                if (_8975)
                {
                    _8981 = all(bool2(_9956.x < 1.0f.xx.x, _9956.y < 1.0f.xx.y));
                }
                else
                {
                    _8981 = _8975;
                }
                bool _8912 = !_8981;
                bool _8919;
                if (!_8912)
                {
                    bool _8986 = all(bool2(_9957.x > 0.0f.xx.x, _9957.y > 0.0f.xx.y));
                    bool _8992;
                    if (_8986)
                    {
                        _8992 = all(bool2(_9957.x < 1.0f.xx.x, _9957.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8992 = _8986;
                    }
                    _8919 = !_8992;
                }
                else
                {
                    _8919 = _8912;
                }
                if (_8919)
                {
                    _10623 = 0.0f;
                    break;
                }
                uint _8999_dummy_parameter;
                uint _9015_dummy_parameter;
                float4 _8940 = mul(float4((float2(_9956.x, 1.0f - _9956.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9956 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8999_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8942 = _8940.w;
                if (abs(_8942) < 9.9999999747524270787835121154785e-07f)
                {
                    _10623 = 0.0f;
                    break;
                }
                float _8953 = abs(cbFI_DeviceToViewDepth.y / ((_8940.z / _8942) - cbFI_DeviceToViewDepth.x));
                float _8956 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9957 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9015_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10623 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8953 - _8956) / max(max(_8953, _8956), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9063 = all(bool2(_9957.x > 0.0f.xx.x, _9957.y > 0.0f.xx.y));
            bool _9069;
            if (_9063)
            {
                _9069 = all(bool2(_9957.x < 1.0f.xx.x, _9957.y < 1.0f.xx.y));
            }
            else
            {
                _9069 = _9063;
            }
            float _10624;
            if (_9069)
            {
                uint _9076_dummy_parameter;
                _10624 = length((_5846 + (r_motion_tp1.Load(int3(int2(floor(_9957 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9076_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10624 = 1000000.0f;
            }
            float _10635;
            if ((_5059 & 1u) != 0u)
            {
                _10635 = _10623;
            }
            else
            {
                _10635 = 1.0f;
            }
            float _10636;
            if ((_5059 & 2u) != 0u)
            {
                _10636 = _10635 * (1.0f - smoothstep(2.0f, 8.0f, _10624));
            }
            else
            {
                _10636 = _10635;
            }
            float _10637;
            if ((_5059 & 4u) != 0u)
            {
                _10637 = _10636 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6567 - _6575) - length(_6551 - _6559))));
            }
            else
            {
                _10637 = _10636;
            }
            float _10849;
            if ((_5059 & 8u) != 0u)
            {
                _10849 = lerp(1.0f, _10637, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6551 - _6559)));
            }
            else
            {
                _10849 = _10637;
            }
            bool _5145 = (_5059 & 16u) != 0u;
            bool _5154;
            if (_5145)
            {
                _5154 = length(_9951 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5154 = _5145;
            }
            float _11908 = _5154 ? 1.0f : _10849;
            bool _5160 = _5065 && _6760;
            bool _5165;
            if (_5160)
            {
                bool _9101 = all(bool2(_9953.x > 0.0f.xx.x, _9953.y > 0.0f.xx.y));
                bool _9107;
                if (_9101)
                {
                    _9107 = all(bool2(_9953.x < 1.0f.xx.x, _9953.y < 1.0f.xx.y));
                }
                else
                {
                    _9107 = _9101;
                }
                _5165 = _9107;
            }
            else
            {
                _5165 = _5160;
            }
            bool _5170;
            if (_5165)
            {
                bool _9112 = all(bool2(_9955.x > 0.0f.xx.x, _9955.y > 0.0f.xx.y));
                bool _9118;
                if (_9112)
                {
                    _9118 = all(bool2(_9955.x < 1.0f.xx.x, _9955.y < 1.0f.xx.y));
                }
                else
                {
                    _9118 = _9112;
                }
                _5170 = _9118;
            }
            else
            {
                _5170 = _5165;
            }
            float4 _10856;
            if (_5170)
            {
                float _5176 = _10838.x + _10838.y;
                float _5185 = (_10838.z + _10838.w) * (1.0f - _11908);
                float _10852;
                if (_5176 > 9.9999997473787516355514526367188e-06f)
                {
                    _10852 = _10838.x / _5176;
                }
                else
                {
                    _10852 = _4172;
                }
                _10856 = float4(_10838.x + (_5185 * _10852), _10838.y + (_5185 * (1.0f - _10852)), _10838.zw * _11908);
            }
            else
            {
                _10856 = _10838;
            }
            _10855 = _10856;
        }
        else
        {
            _10855 = _10838;
        }
        float3 _11676;
        if (_10858)
        {
            float3 _9124 = r_current_interpolation_source.Load(int3(_3560, 0)).xyz;
            float3 _11677;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6760)
            {
                uint _9131_dummy_parameter;
                float _10963;
                _10963 = r_depth_tm1.Load(int3(int2(floor(_9953 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9131_dummy_parameter))))), 0)).x;
                float _5297;
                for (int _10962 = 0; _10962 < 24; _10963 = _5297, _10962++)
                {
                    float _5269 = float(_10962 & 7) * 0.785398185253143310546875f;
                    int _5271 = _10962 >> 3;
                    int _11727;
                    if (_5271 == 0)
                    {
                        _11727 = 16;
                    }
                    else
                    {
                        _11727 = (_5271 == 1) ? 48 : 96;
                    }
                    uint _9151_dummy_parameter;
                    _5297 = min(_10963, r_depth_tm1.Load(int3(int2(floor(clamp(_9953 + ((cbFI_MvDepthLaneSizeRcp * float(_11727)) * float2(cos(_5269), sin(_5269))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9151_dummy_parameter))))), 0)).x);
                }
                float2 _10964;
                do
                {
                    float _9173 = 1.0f - _9953.y;
                    float4 _9184 = mul(float4((float2(_9953.x, _9173) * 2.0f) - 1.0f.xx, _10963, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9186 = _9184.w;
                    if (!(_9186 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10964 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9199 = ((_9184.xy / _9186.xx) + 1.0f.xx) * 0.5f;
                    _10964 = float2(_9199.x - _9953.x, _9173 - _9199.y);
                    break;
                } while(false);
                float2 _5308 = _9953 + _10964;
                bool _9217 = all(bool2(_5308.x > 0.0f.xx.x, _5308.y > 0.0f.xx.y));
                bool _9223;
                if (_9217)
                {
                    _9223 = all(bool2(_5308.x < 1.0f.xx.x, _5308.y < 1.0f.xx.y));
                }
                else
                {
                    _9223 = _9217;
                }
                float3 _11678;
                if (_9223)
                {
                    float _5314 = abs(cbFI_DeviceToViewDepth.y / (_10963 - cbFI_DeviceToViewDepth.x));
                    uint _9243_dummy_parameter;
                    int2 _9243 = int2(spvTextureSize(r_depth_m2, uint(0), _9243_dummy_parameter));
                    float _5318 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5308 * float2(_9243))), int2(0, 0), _9243 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11683;
                    if (abs(_5318 - _5314) <= (0.20000000298023223876953125f * max(_5318, _5314)))
                    {
                        uint _9277_dummy_parameter;
                        int2 _9277 = int2(spvTextureSize(r_colour_m2, uint(0), _9277_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9300;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9300);
                        }
                        _11683 = r_colour_m2.Load(int3(clamp(int2(floor(_5308 * float2(_9277))), int2(0, 0), _9277 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9310;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9310);
                        }
                        _11683 = _9124;
                    }
                    _11678 = _11683;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9320;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9320);
                    }
                    _11678 = _9124;
                }
                _11677 = _11678;
            }
            else
            {
                _11677 = _9124;
            }
            _11676 = _11677;
        }
        else
        {
            _11676 = (((_6551 * _10855.x) + (_6559 * _10855.y)) + (_6567 * _10855.z)) + (_6575 * _10855.w);
        }
        uint _5346 = cbFI_pad0 & 255u;
        bool _11568;
        float3 _11675;
        if (_5346 != 0u)
        {
            float3 _5351 = r_present_backbuffer.Load(int3(_3560, 0)).xyz;
            float3 _5355 = r_current_interpolation_source.Load(int3(_3560, 0)).xyz;
            float3 _5359 = abs(_5351 - _5355);
            float3 _10967;
            if (_5346 == 2u)
            {
                _10967 = (abs(_5355) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _10967 = 0.000244140625f.xxx;
            }
            bool _5375 = any(bool3(_5359.x > _10967.x, _5359.y > _10967.y, _5359.z > _10967.z));
            bool3 _11909 = _5375.xxx;
            _11675 = float3(_11909.x ? _5351.x : _11676.x, _11909.y ? _5351.y : _11676.y, _11909.z ? _5351.z : _11676.z);
            _11568 = _5375;
        }
        else
        {
            _11675 = _11676;
            _11568 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9335;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9335);
        }
        float3 _11658;
        if (_5063 == 1u)
        {
            _11658 = lerp(_6551, _6559, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11659;
            if (_5063 == 2u)
            {
                _11659 = lerp(_6567, _6575, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11660;
                if (_5063 == 3u)
                {
                    _11660 = float(_11568).xxx;
                }
                else
                {
                    float3 _11661;
                    if (_5063 == 4u)
                    {
                        _11661 = float3(((_9951 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11662;
                        if (_5063 == 5u)
                        {
                            _11662 = float3(((_5846 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11663;
                            if (_5063 == 6u)
                            {
                                _11663 = float3(_10855.xy, _10855.z + _10855.w);
                            }
                            else
                            {
                                float3 _11664;
                                if (_5063 == 7u)
                                {
                                    _11664 = r_current_interpolation_source.Load(int3(_3560, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11665;
                                    if (_5063 == 8u)
                                    {
                                        _11665 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3947, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11666;
                                        if (_5067)
                                        {
                                            uint _9357_dummy_parameter;
                                            uint _9389_dummy_parameter;
                                            _11666 = float3(log((r_depth_tp1.Load(int3(int2(floor(_3947 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9357_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_3947 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9389_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11667;
                                            if (_5070)
                                            {
                                                _11667 = _6567;
                                            }
                                            else
                                            {
                                                float3 _11668;
                                                if (_5063 == 20u)
                                                {
                                                    _11668 = _6551;
                                                }
                                                else
                                                {
                                                    float3 _11669;
                                                    if (_5063 == 21u)
                                                    {
                                                        _11669 = _6559;
                                                    }
                                                    else
                                                    {
                                                        float3 _11670;
                                                        if (_5063 == 22u)
                                                        {
                                                            _11670 = _6575;
                                                        }
                                                        else
                                                        {
                                                            float3 _11671;
                                                            if (_5063 == 18u)
                                                            {
                                                                _11671 = _11336;
                                                            }
                                                            else
                                                            {
                                                                float3 _11672;
                                                                if (_5063 == 19u)
                                                                {
                                                                    _11672 = _11151;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _11911 = (_5063 == 23u).xxx;
                                                                    _11672 = float3(_11911.x ? _10972.x : _11675.x, _11911.y ? _10972.y : _11675.y, _11911.z ? _10972.z : _11675.z);
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
                                    _11664 = _11665;
                                }
                                _11663 = _11664;
                            }
                            _11662 = _11663;
                        }
                        _11661 = _11662;
                    }
                    _11660 = _11661;
                }
                _11659 = _11660;
            }
            _11658 = _11659;
        }
        float3 _11657;
        if ((_5063 >= 9u) && (_5063 <= 11u))
        {
            uint _5539 = 64u + uint((_9983.y * cbFI_MvDepthLaneSize.x) + _9983.x);
            uint _5543 = rw_nfru_diagnostics.Load<uint>(_5539 * 4 + 0) & 15u;
            float3 _11688;
            if (_5063 == 10u)
            {
                float3 _11656;
                if ((rw_nfru_diagnostics.Load<uint>(_5539 * 4 + 0) & 32u) != 0u)
                {
                    _11656 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11655;
                    if ((rw_nfru_diagnostics.Load<uint>(_5539 * 4 + 0) & 16u) != 0u)
                    {
                        _11655 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5564 = ((rw_nfru_diagnostics.Load<uint>(_5539 * 4 + 0) & 64u) != 0u).xxx;
                        _11655 = float3(_5564.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5564.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5564.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11656 = _11655;
                }
                _11688 = _11656;
            }
            else
            {
                float3 _11689;
                if (_5063 == 11u)
                {
                    uint _5577 = (rw_nfru_diagnostics.Load<uint>(_5539 * 4 + 0) >> 8u) & 15u;
                    uint _5580 = (rw_nfru_diagnostics.Load<uint>(_5539 * 4 + 0) >> 12u) & 15u;
                    float3 _11648;
                    if ((_5543 == 2u) || (_5543 == 3u))
                    {
                        _11648 = _3273[_5543];
                    }
                    else
                    {
                        bool _5592 = _5577 == 3u;
                        bool _5594 = _5580 == 3u;
                        float3 _11649;
                        if (_5592 && _5594)
                        {
                            _11649 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11650;
                            if (_5592)
                            {
                                _11650 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11651;
                                if (_5594)
                                {
                                    _11651 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11652;
                                    if ((_5577 == 4u) || (_5580 == 4u))
                                    {
                                        _11652 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11653;
                                        if ((_5577 == 1u) || (_5580 == 1u))
                                        {
                                            _11653 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _11913 = (_5543 == 1u).xxx;
                                            _11653 = float3(_11913.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _11913.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _11913.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _11652 = _11653;
                                    }
                                    _11651 = _11652;
                                }
                                _11650 = _11651;
                            }
                            _11649 = _11650;
                        }
                        _11648 = _11649;
                    }
                    _11689 = _11648;
                }
                else
                {
                    _11689 = _3273[min(_5543, 7u)];
                }
                _11688 = _11689;
            }
            _11657 = _11688;
        }
        else
        {
            _11657 = _11658;
        }
        float4 _11692;
        if ((_5063 >= 14u) && (_5063 <= 16u))
        {
            float2 _11690;
            if (_5063 == 14u)
            {
                uint _5650_dummy_parameter;
                uint _5656_dummy_parameter;
                _11690 = r_flow_tm1.Load(int3(clamp(int2(floor(_3947 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5650_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5656_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11691;
                if (_5063 == 16u)
                {
                    uint _9440 = r_warped_flow_qdata_tm1.Load(int3(_3963, 0)).x & 2147483647u;
                    uint _9472 = uint(max((int((_9440 >> 16u) & 15u) - 6), 0));
                    _11691 = ((float2(float((1 - (2 * int((_9440 >> 15u) & 1u))) * int(((_9440 >> uint(7)) & 127u) << _9472)), float((1 - (2 * int((_9440 >> 14u) & 1u))) * int((_9440 & 127u) << _9472))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11691 = _5846 * float2(cbFI_DisplaySize);
                }
                _11690 = _11691;
            }
            uint2 _5689 = uint2(clamp(round(_11690 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5691 = _5689.x;
            uint _5698 = _5689.y;
            _11692 = float4(float(_5691 & 255u), float((_5691 >> 8u) | ((_5698 & 15u) << 4u)), float(_5698 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11693;
            if (_5063 == 17u)
            {
                _11693 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3963, 0)).x != 0u), _4306, 0.0f, 1.0f);
            }
            else
            {
                _11693 = float4(_11657, 1.0f);
            }
            _11692 = _11693;
        }
        rw_output[_3560] = _11692.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5742 = ((uint(_3560.y) * uint(cbFI_DisplaySize.x)) + uint(_3560.x)) * 6u;
            uint _9518 = spvPackHalf2x16(clamp(_6550.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5742 * 4 + 0, (((_9518 & 32767u) >> 4u) | ((((_9518 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6550.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9553 = spvPackHalf2x16(clamp(_6558.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5742 + 1u) * 4 + 0, (((_9553 & 32767u) >> 4u) | ((((_9553 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6558.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9588 = spvPackHalf2x16(clamp(_6566.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5742 + 2u) * 4 + 0, (((_9588 & 32767u) >> 4u) | ((((_9588 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6566.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9623 = spvPackHalf2x16(clamp(_6574.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5742 + 3u) * 4 + 0, (((_9623 & 32767u) >> 4u) | ((((_9623 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6574.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9650 = r_current_interpolation_source.Load(int3(_3560, 0));
            uint _9664 = spvPackHalf2x16(clamp(_9650.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5742 + 4u) * 4 + 0, (((_9664 & 32767u) >> 4u) | ((((_9664 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9650.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11726;
            if (_11568 || (_5063 != 0u))
            {
                _11726 = 4294967295u;
            }
            else
            {
                uint _9699 = spvPackHalf2x16(clamp(_11692.xy, 0.0f.xx, 65000.0f.xx));
                _11726 = (((_9699 & 32767u) >> 4u) | ((((_9699 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11692.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5742 + 5u) * 4 + 0, _11726);
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
