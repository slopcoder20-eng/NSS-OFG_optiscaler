static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3434[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3721 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3721.x >= cbFI_DisplaySize.x, _3721.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3721] = float4(r_present_backbuffer.Load(int3(_3721, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4124 = (float2(_3721) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4135 = int2(floor(_4124 * float2(cbFI_MvDepthLaneSize)));
        int2 _4140 = int2(floor(_4124 * float2(cbFI_FlowLaneSize)));
        float4 _6163 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4124 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6169 = r_warped_filled_flow_tm1.Load(int3(_4140, 0)).xy;
        float2 _6175 = r_warped_filled_motion_tp1.Load(int3(_4135, 0)).xy;
        bool _6197 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10410;
        if (_6197)
        {
            float _6210 = ((2.0f * _4124.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10410 = float2(atan(_6210) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4124.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6210 * _6210))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10410 = _4124;
        }
        bool _4161 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10431;
        bool _10452;
        int2 _10463;
        float3 _11969;
        if (_4161)
        {
            float _10412;
            float _10414;
            _10414 = 2.0f;
            _10412 = -1.0f;
            uint _3783[9];
            float _12422;
            float _12425;
            for (int _10411 = 0; _10411 < 9; _10414 = _12425, _10412 = _12422, _10411++)
            {
                _3783[_10411] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4135 + int2((_10411 % 3) - 1, (_10411 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3783[_10411] != 0u)
                {
                    float _12417;
                    if (_3783[_10411] == 0u)
                    {
                        _12417 = -1.0f;
                    }
                    else
                    {
                        _12417 = float((_3783[_10411] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12425 = min(_10414, _12417);
                    _12422 = max(_10412, _12417);
                }
                else
                {
                    _12425 = _10414;
                    _12422 = _10412;
                }
            }
            float _4207 = float(_10412 >= 0.0f);
            float3 _10197 = 0.0f.xxx;
            _10197.y = _4207;
            float2 _10432;
            bool _10453;
            int2 _10464;
            float3 _11970;
            if ((_10412 - _10414) > 0.0199999995529651641845703125f)
            {
                float _10420;
                int2 _10421;
                float2 _10422;
                int2 _10424;
                float2 _10430;
                _10430 = _6175;
                _10424 = _4135;
                _10422 = _6175;
                _10421 = _4135;
                _10420 = -1.0f;
                float _12430;
                int2 _12434;
                float2 _12445;
                int2 _12456;
                float2 _12489;
                float _12536;
                int _10419 = 0;
                float _12398 = 1000000000.0f;
                for (; _10419 < 9; _12398 = _12536, _10430 = _12489, _10424 = _12456, _10422 = _12445, _10421 = _12434, _10420 = _12430, _10419++)
                {
                    if (_3783[_10419] == 0u)
                    {
                        _12536 = _12398;
                        _12489 = _10430;
                        _12456 = _10424;
                        _12445 = _10422;
                        _12434 = _10421;
                        _12430 = _10420;
                        continue;
                    }
                    int2 _4242 = clamp(_4135 + int2((_10419 % 3) - 1, (_10419 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6285 = _3783[_10419] & 2147483647u;
                    uint _6317 = uint(max((int((_6285 >> 16u) & 15u) - 6), 0));
                    float2 _4248 = (float2(float((1 - (2 * int((_6285 >> 15u) & 1u))) * int(((_6285 >> uint(7)) & 127u) << _6317)), float((1 - (2 * int((_6285 >> 14u) & 1u))) * int((_6285 & 127u) << _6317))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12384;
                    if (_3783[_10419] == 0u)
                    {
                        _12384 = -1.0f;
                    }
                    else
                    {
                        _12384 = float((_3783[_10419] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4253 = _12384 - 0.100000001490116119384765625f;
                    float2 _12385;
                    if (_6197)
                    {
                        float2 _6394 = clamp((((_10410 + (_4248 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6397 = tan(_6394.x);
                        _12385 = (float2(_6397 / cbFI_DeviceToViewDepth.z, (tan(_6394.y) * sqrt(1.0f + (_6397 * _6397))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12385 = _10410 + (_4248 * cbFI_Timestep);
                    }
                    float _4260 = cbFI_Timestep - 1.0f;
                    float2 _12386;
                    if (_6197)
                    {
                        float2 _6465 = clamp((((_10410 + (_4248 * _4260)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6468 = tan(_6465.x);
                        _12386 = (float2(_6468 / cbFI_DeviceToViewDepth.z, (tan(_6465.y) * sqrt(1.0f + (_6468 * _6468))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12386 = _10410 + (_4248 * _4260);
                    }
                    bool _6501 = all(bool2(_12385.x > 0.0f.xx.x, _12385.y > 0.0f.xx.y));
                    bool _6507;
                    if (_6501)
                    {
                        _6507 = all(bool2(_12385.x < 1.0f.xx.x, _12385.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6507 = _6501;
                    }
                    float _12389;
                    if (_6507)
                    {
                        uint _6514_dummy_parameter;
                        _12389 = max((_4253 - (log((r_depth_tm1.Load(int3(int2(floor(_12385 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6514_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12389 = 0.0f;
                    }
                    bool _6544 = all(bool2(_12386.x > 0.0f.xx.x, _12386.y > 0.0f.xx.y));
                    bool _6550;
                    if (_6544)
                    {
                        _6550 = all(bool2(_12386.x < 1.0f.xx.x, _12386.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6550 = _6544;
                    }
                    float _12390;
                    if (_6550)
                    {
                        uint _6557_dummy_parameter;
                        _12390 = _12389 + max((_4253 - (log((r_depth_tp1.Load(int3(int2(floor(_12386 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6557_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12390 = _12389;
                    }
                    float _12431;
                    int2 _12435;
                    float2 _12446;
                    int2 _12457;
                    float2 _12490;
                    float _12537;
                    if (_12390 == 0.0f)
                    {
                        bool _4295 = _4253 > _10420;
                        bool2 _12545 = _4295.xx;
                        _12537 = _12398;
                        _12490 = float2(_12545.x ? _4248.x : _10430.x, _12545.y ? _4248.y : _10430.y);
                        _12457 = int2(_12545.x ? _4242.x : _10424.x, _12545.y ? _4242.y : _10424.y);
                        _12446 = _10422;
                        _12435 = _10421;
                        _12431 = _4295 ? _4253 : _10420;
                    }
                    else
                    {
                        bool _4304 = _12390 < _12398;
                        bool2 _12541 = _4304.xx;
                        _12537 = _4304 ? _12390 : _12398;
                        _12490 = _10430;
                        _12457 = _10424;
                        _12446 = float2(_12541.x ? _4248.x : _10422.x, _12541.y ? _4248.y : _10422.y);
                        _12435 = int2(_12541.x ? _4242.x : _10421.x, _12541.y ? _4242.y : _10421.y);
                        _12431 = _10420;
                    }
                    _12536 = _12537;
                    _12489 = _12490;
                    _12456 = _12457;
                    _12445 = _12446;
                    _12434 = _12435;
                    _12430 = _12431;
                }
                bool _4316 = _10420 < 0.0f;
                bool2 _12551 = _4316.xx;
                int2 _12554 = int2(_12551.x ? _10421.x : _10424.x, _12551.y ? _10421.y : _10424.y);
                _11970 = float3(1.0f, _4207, float(any(bool2(_12554.x != _4135.x, _12554.y != _4135.y))));
                _10464 = _12554;
                _10453 = _4316 ? false : true;
                _10432 = float2(_12551.x ? _10422.x : _10430.x, _12551.y ? _10422.y : _10430.y);
            }
            else
            {
                _11970 = _10197;
                _10464 = _4135;
                _10453 = false;
                _10432 = _6175;
            }
            _11969 = _11970;
            _10463 = _10464;
            _10452 = _10453;
            _10431 = _10432;
        }
        else
        {
            _11969 = 0.0f.xxx;
            _10463 = _4135;
            _10452 = false;
            _10431 = _6175;
        }
        float2 _10433;
        if (_6197)
        {
            float2 _6622 = clamp((((_10410 + (_10431 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6625 = tan(_6622.x);
            _10433 = (float2(_6625 / cbFI_DeviceToViewDepth.z, (tan(_6622.y) * sqrt(1.0f + (_6625 * _6625))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10433 = _10410 + (_10431 * cbFI_Timestep);
        }
        float _4339 = cbFI_Timestep - 1.0f;
        float2 _10435;
        if (_6197)
        {
            float2 _6693 = clamp((((_10410 + (_10431 * _4339)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6696 = tan(_6693.x);
            _10435 = (float2(_6696 / cbFI_DeviceToViewDepth.z, (tan(_6693.y) * sqrt(1.0f + (_6696 * _6696))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10435 = _10410 + (_10431 * _4339);
        }
        float _4344 = -cbFI_Timestep;
        float2 _10436;
        if (_6197)
        {
            float2 _6764 = clamp((((_10410 + (_6169 * _4344)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6767 = tan(_6764.x);
            _10436 = (float2(_6767 / cbFI_DeviceToViewDepth.z, (tan(_6764.y) * sqrt(1.0f + (_6767 * _6767))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10436 = _10410 + (_6169 * _4344);
        }
        float _4349 = 1.0f - cbFI_Timestep;
        float2 _10437;
        if (_6197)
        {
            float2 _6835 = clamp((((_10410 + (_6169 * _4349)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6838 = tan(_6835.x);
            _10437 = (float2(_6838 / cbFI_DeviceToViewDepth.z, (tan(_6835.y) * sqrt(1.0f + (_6838 * _6838))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10437 = _10410 + (_6169 * _4349);
        }
        float4 _6873 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10433, 0.0f);
        float3 _6874 = _6873.xyz;
        float4 _6881 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10435, 0.0f);
        float3 _6882 = _6881.xyz;
        float4 _6889 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10436, 0.0f);
        float3 _6890 = _6889.xyz;
        float4 _6897 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10437, 0.0f);
        float3 _6898 = _6897.xyz;
        float4 _6912 = exp(_6163 - max(max(max(_6163.x, _6163.y), _6163.z), _6163.w).xxxx);
        float4 _6919 = _6912 / (dot(_6912, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4368 = _4161 && (!_10452);
        bool _4377;
        if (_4368)
        {
            _4377 = (_6919.z + _6919.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4377 = _4368;
        }
        bool _4388;
        if (_4377)
        {
            _4388 = length((_10436 - _10433) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4388 = _4377;
        }
        bool _10476;
        if (_4388)
        {
            uint4 _6938 = r_warped_motion_qdata_tp1.Load(int3(_10463, 0));
            uint _6939 = _6938.x;
            bool _10479;
            if (_6939 != 0u)
            {
                float _10465;
                if (_6939 == 0u)
                {
                    _10465 = -1.0f;
                }
                else
                {
                    _10465 = float((_6939 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4398 = _10465 - 0.12000000476837158203125f;
                bool _6958 = all(bool2(_10436.x > 0.0f.xx.x, _10436.y > 0.0f.xx.y));
                bool _6964;
                if (_6958)
                {
                    _6964 = all(bool2(_10436.x < 1.0f.xx.x, _10436.y < 1.0f.xx.y));
                }
                else
                {
                    _6964 = _6958;
                }
                bool _4408;
                if (_6964)
                {
                    uint _6971_dummy_parameter;
                    _4408 = (log((r_depth_tm1.Load(int3(int2(floor(_10436 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6971_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4398;
                }
                else
                {
                    _4408 = _6964;
                }
                bool _4422;
                if (!_4408)
                {
                    bool _7001 = all(bool2(_10437.x > 0.0f.xx.x, _10437.y > 0.0f.xx.y));
                    bool _7007;
                    if (_7001)
                    {
                        _7007 = all(bool2(_10437.x < 1.0f.xx.x, _10437.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7007 = _7001;
                    }
                    bool _4420;
                    if (_7007)
                    {
                        uint _7014_dummy_parameter;
                        _4420 = (log((r_depth_tp1.Load(int3(int2(floor(_10437 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7014_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4398;
                    }
                    else
                    {
                        _4420 = _7007;
                    }
                    _4422 = _4420;
                }
                else
                {
                    _4422 = _4408;
                }
                _10479 = _4422;
            }
            else
            {
                _10479 = false;
            }
            _10476 = _10479;
        }
        else
        {
            _10476 = false;
        }
        bool _4427 = _10452 || _10476;
        bool _4432;
        if (_4427)
        {
            bool _7044 = all(bool2(_10433.x > 0.0f.xx.x, _10433.y > 0.0f.xx.y));
            bool _7050;
            if (_7044)
            {
                _7050 = all(bool2(_10433.x < 1.0f.xx.x, _10433.y < 1.0f.xx.y));
            }
            else
            {
                _7050 = _7044;
            }
            _4432 = _7050;
        }
        else
        {
            _4432 = _4427;
        }
        bool _4437;
        if (_4432)
        {
            bool _7055 = all(bool2(_10435.x > 0.0f.xx.x, _10435.y > 0.0f.xx.y));
            bool _7061;
            if (_7055)
            {
                _7061 = all(bool2(_10435.x < 1.0f.xx.x, _10435.y < 1.0f.xx.y));
            }
            else
            {
                _7061 = _7055;
            }
            _4437 = _7061;
        }
        else
        {
            _4437 = _4432;
        }
        float4 _10573;
        if (_4437)
        {
            float _4440 = _6919.x;
            float _4442 = _6919.y;
            float _4443 = _4440 + _4442;
            float _4448 = _6919.z + _6919.w;
            float _10494;
            if (_4443 > 0.001000000047497451305389404296875f)
            {
                _10494 = _4440 / _4443;
            }
            else
            {
                _10494 = _4349;
            }
            _10573 = float4(_4440 + (_4448 * _10494), _4442 + (_4448 * (1.0f - _10494)), 0.0f, 0.0f);
        }
        else
        {
            _10573 = _6919;
        }
        bool _7089 = (cbFI_pad0 & 1024u) != 0u;
        bool _7065 = !_7089;
        bool _7066 = !_7065;
        bool _7083;
        if (_7066)
        {
            _7083 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10463.y * cbFI_MvDepthLaneSize.x) + _10463.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _7083 = _7065;
        }
        bool _7115;
        if (_7066)
        {
            _7115 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4140.y * cbFI_FlowLaneSize.x) + _4140.x)) * 4 + 0) != 0u;
        }
        else
        {
            _7115 = _7065;
        }
        float _4483 = float(_7115);
        bool _10586;
        float4 _10617;
        float3 _11762;
        if (_7089)
        {
            bool _4493;
            if (_7083)
            {
                _4493 = all(bool2(_10433.x > 0.0f.xx.x, _10433.y > 0.0f.xx.y));
            }
            else
            {
                _4493 = _7083;
            }
            bool _4499;
            if (_4493)
            {
                _4499 = all(bool2(_10433.x < 1.0f.xx.x, _10433.y < 1.0f.xx.y));
            }
            else
            {
                _4499 = _4493;
            }
            bool _4506;
            if (_7083)
            {
                _4506 = all(bool2(_10435.x > 0.0f.xx.x, _10435.y > 0.0f.xx.y));
            }
            else
            {
                _4506 = _7083;
            }
            bool _4512;
            if (_4506)
            {
                _4512 = all(bool2(_10435.x < 1.0f.xx.x, _10435.y < 1.0f.xx.y));
            }
            else
            {
                _4512 = _4506;
            }
            bool _4519;
            if (_7115)
            {
                _4519 = all(bool2(_10436.x > 0.0f.xx.x, _10436.y > 0.0f.xx.y));
            }
            else
            {
                _4519 = _7115;
            }
            bool _4525;
            if (_4519)
            {
                _4525 = all(bool2(_10436.x < 1.0f.xx.x, _10436.y < 1.0f.xx.y));
            }
            else
            {
                _4525 = _4519;
            }
            bool _4532;
            if (_7115)
            {
                _4532 = all(bool2(_10437.x > 0.0f.xx.x, _10437.y > 0.0f.xx.y));
            }
            else
            {
                _4532 = _7115;
            }
            bool _4538;
            if (_4532)
            {
                _4538 = all(bool2(_10437.x < 1.0f.xx.x, _10437.y < 1.0f.xx.y));
            }
            else
            {
                _4538 = _4532;
            }
            bool _4540 = !_7083;
            if (_4540)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7157;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7157);
                }
            }
            bool _4545 = !_7115;
            if (_4545)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7167;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7167);
                }
            }
            if (_7083 && _4545)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7177;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7177);
                }
            }
            if (_4540 && _7115)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7187;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7187);
                }
            }
            float _4564 = float(_4499);
            float _4566 = float(_4512);
            bool _4569 = _4525 && _4538;
            float _10528;
            if (_4569)
            {
                _10528 = 1.0f;
            }
            else
            {
                _10528 = (_4525 || _4538) ? 0.5f : 0.0f;
            }
            bool _10533;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4499)) && (!_4512))
            {
                bool _4599;
                if (_4569)
                {
                    float _10531;
                    do
                    {
                        bool _7271 = all(bool2(_10436.x > 0.0f.xx.x, _10436.y > 0.0f.xx.y));
                        bool _7277;
                        if (_7271)
                        {
                            _7277 = all(bool2(_10436.x < 1.0f.xx.x, _10436.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7277 = _7271;
                        }
                        bool _7208 = !_7277;
                        bool _7215;
                        if (!_7208)
                        {
                            bool _7282 = all(bool2(_10437.x > 0.0f.xx.x, _10437.y > 0.0f.xx.y));
                            bool _7288;
                            if (_7282)
                            {
                                _7288 = all(bool2(_10437.x < 1.0f.xx.x, _10437.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7288 = _7282;
                            }
                            _7215 = !_7288;
                        }
                        else
                        {
                            _7215 = _7208;
                        }
                        if (_7215)
                        {
                            _10531 = 0.0f;
                            break;
                        }
                        uint _7295_dummy_parameter;
                        uint _7311_dummy_parameter;
                        float4 _7236 = mul(float4((float2(_10436.x, 1.0f - _10436.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10436 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7295_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7238 = _7236.w;
                        if (abs(_7238) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10531 = 0.0f;
                            break;
                        }
                        float _7249 = abs(cbFI_DeviceToViewDepth.y / ((_7236.z / _7238) - cbFI_DeviceToViewDepth.x));
                        float _7252 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10437 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7311_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10531 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7249 - _7252) / max(max(_7249, _7252), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4599 = _10531 >= 0.5f;
                }
                else
                {
                    _4599 = _4569;
                }
                bool _4607;
                if (_4599)
                {
                    _4607 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4607 = _4599;
                }
                bool _10534;
                if (_4607)
                {
                    uint _7361_dummy_parameter;
                    float2 _10532;
                    do
                    {
                        float _7387 = 1.0f - _10436.y;
                        float4 _7398 = mul(float4((float2(_10436.x, _7387) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10436 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7361_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7400 = _7398.w;
                        if (!(_7400 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10532 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7413 = ((_7398.xy / _7400.xx) + 1.0f.xx) * 0.5f;
                        _10532 = float2(_7413.x - _10436.x, _7387 - _7413.y);
                        break;
                    } while(false);
                    float2 _4620 = float2(cbFI_DisplaySize);
                    _10534 = length(((_10436 + _10532) - _10437) * _4620) <= ((0.100000001490116119384765625f * length(_10532 * _4620)) + 8.0f);
                }
                else
                {
                    _10534 = _4599;
                }
                _10533 = _10534;
            }
            else
            {
                _10533 = true;
            }
            bool _4634 = !_10533;
            bool _12555 = _4634 ? false : _4538;
            bool _12556 = _4634 ? false : _4525;
            bool _10587;
            float4 _10618;
            if (!(((_4499 && _4512) && _12556) && _12555))
            {
                float4 _4656 = _10573 * float4(_4564, _4566, float(_12556), float(_12555));
                float _4658 = dot(_4656, 1.0f.xxxx);
                bool _4661 = !(_4658 > 0.0f);
                float4 _10619;
                if (!_4661)
                {
                    _10619 = _4656 / _4658.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7435;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7435);
                    }
                    _10619 = 0.0f.xxxx;
                }
                _10618 = _10619;
                _10587 = _4661;
            }
            else
            {
                _10618 = _10573;
                _10587 = false;
            }
            _11762 = float3(_4564, _4566, _10528);
            _10617 = _10618;
            _10586 = _10587;
        }
        else
        {
            _11762 = float3(float(_7083), _4483, 0.0f);
            _10617 = _10573;
            _10586 = false;
        }
        bool _4679 = !_10586;
        float4 _10681;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4679)
        {
            float _4686 = _10617.x + _10617.y;
            float4 _10682;
            if (_4686 > 0.001000000047497451305389404296875f)
            {
                _10682 = float4(_10617.x / _4686, _10617.y / _4686, 0.0f, 0.0f);
            }
            else
            {
                _10682 = float4(_4349, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10681 = _10682;
        }
        else
        {
            _10681 = _10617;
        }
        float4 _10838;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4679) && _7083)
        {
            float _10676;
            do
            {
                uint4 _7575 = r_warped_motion_qdata_tp1.Load(int3(_10463, 0));
                uint _7576 = _7575.x;
                if (_7576 != 0u)
                {
                    float _10675;
                    if (_7576 == 0u)
                    {
                        _10675 = -1.0f;
                    }
                    else
                    {
                        _10675 = float((_7576 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10676 = _10675;
                    break;
                }
                int _10658;
                uint _10659;
                _10659 = _7576;
                _10658 = -1;
                uint _10674;
                for (; _10658 <= 1; _10659 = _10674, _10658++)
                {
                    _10674 = _10659;
                    for (int _10672 = -1; _10672 <= 1; )
                    {
                        _10674 = max(_10674, r_warped_motion_qdata_tp1.Load(int3(clamp(_10463 + int2(_10672, _10658), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10672++;
                        continue;
                    }
                }
                if (_10659 != 0u)
                {
                    float _10671;
                    if (_10659 == 0u)
                    {
                        _10671 = -1.0f;
                    }
                    else
                    {
                        _10671 = float((_10659 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10676 = _10671;
                    break;
                }
                uint _10661;
                _10661 = 4294967295u;
                uint _12526;
                for (int _10660 = 0; _10660 < 8; _10661 = _12526, _10660++)
                {
                    int _10664 = 0;
                    for (;;)
                    {
                        if (_10664 < 5)
                        {
                            int2 _7526 = _10463 + (_1085[_10660] * _1094[_10664].xx);
                            bool _7529 = any(bool2(_7526.x < int2(0, 0).x, _7526.y < int2(0, 0).y));
                            bool _7537;
                            if (!_7529)
                            {
                                _7537 = any(bool2(_7526.x >= cbFI_MvDepthLaneSize.x, _7526.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7537 = _7529;
                            }
                            if (_7537)
                            {
                                _12526 = _10661;
                                break;
                            }
                            uint4 _7615 = r_warped_motion_qdata_tp1.Load(int3(_7526, 0));
                            uint _7616 = _7615.x;
                            if (_7616 != 0u)
                            {
                                _12526 = min(_10661, _7616);
                                break;
                            }
                            _10664++;
                            continue;
                        }
                        else
                        {
                            _12526 = _10661;
                            break;
                        }
                    }
                }
                float _10663;
                if (_10661 == 4294967295u)
                {
                    _10663 = -1.0f;
                }
                else
                {
                    float _10662;
                    if (_10661 == 0u)
                    {
                        _10662 = -1.0f;
                    }
                    else
                    {
                        _10662 = float((_10661 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10663 = _10662;
                }
                _10676 = _10663;
                break;
            } while(false);
            float _4722 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4724 = _10676 < 0.0f;
            bool _4729;
            if (_4724)
            {
                bool _7635 = all(bool2(_10433.x > 0.0f.xx.x, _10433.y > 0.0f.xx.y));
                bool _7641;
                if (_7635)
                {
                    _7641 = all(bool2(_10433.x < 1.0f.xx.x, _10433.y < 1.0f.xx.y));
                }
                else
                {
                    _7641 = _7635;
                }
                _4729 = _7641;
            }
            else
            {
                _4729 = _4724;
            }
            bool _4734;
            if (_4729)
            {
                bool _7646 = all(bool2(_10435.x > 0.0f.xx.x, _10435.y > 0.0f.xx.y));
                bool _7652;
                if (_7646)
                {
                    _7652 = all(bool2(_10435.x < 1.0f.xx.x, _10435.y < 1.0f.xx.y));
                }
                else
                {
                    _7652 = _7646;
                }
                _4734 = _7652;
            }
            else
            {
                _4734 = _4729;
            }
            float4 _10738;
            if (_4734)
            {
                uint _7659_dummy_parameter;
                float _7683 = log((r_depth_tm1.Load(int3(int2(floor(_10433 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7659_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _7691_dummy_parameter;
                float _7715 = log((r_depth_tp1.Load(int3(int2(floor(_10435 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7691_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _4745 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4752;
                if (_4745)
                {
                    _4752 = _7715 > (_7683 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4752 = _4745;
                }
                float4 _10712;
                if (_4752)
                {
                    _10712 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10712 = 1.0f.xxxx;
                }
                bool _4759 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4766;
                if (_4759)
                {
                    _4766 = _7683 > (_7715 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4766 = _4759;
                }
                float4 _10741;
                if (_4766)
                {
                    float4 _10267 = _10712;
                    _10267.x = 0.0f;
                    _10741 = _10267;
                }
                else
                {
                    _10741 = _10712;
                }
                _10738 = _10741;
            }
            else
            {
                bool _4774 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4780;
                if (_4774)
                {
                    _4780 = _10681.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4780 = _4774;
                }
                bool _4785;
                if (_4780)
                {
                    bool _7721 = all(bool2(_10435.x > 0.0f.xx.x, _10435.y > 0.0f.xx.y));
                    bool _7727;
                    if (_7721)
                    {
                        _7727 = all(bool2(_10435.x < 1.0f.xx.x, _10435.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7727 = _7721;
                    }
                    _4785 = _7727;
                }
                else
                {
                    _4785 = _4780;
                }
                float4 _10739;
                if (_4785)
                {
                    float _10699;
                    if (_10676 >= 0.0f)
                    {
                        _10699 = _10676 - _4722;
                    }
                    else
                    {
                        float _10695;
                        _10695 = 2.0f;
                        float _7784;
                        for (int _10694 = 0; _10694 < 24; _10695 = _7784, _10694++)
                        {
                            float _7748 = float(_10694 & 7) * 0.785398185253143310546875f;
                            int _7750 = _10694 >> 3;
                            int _10696;
                            if (_7750 == 0)
                            {
                                _10696 = 16;
                            }
                            else
                            {
                                _10696 = (_7750 == 1) ? 48 : 96;
                            }
                            uint _7816_dummy_parameter;
                            _7784 = min(_10695, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10435 + ((cbFI_MvDepthLaneSizeRcp * float(_10696)) * float2(cos(_7748), sin(_7748))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7816_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10699 = _10695;
                    }
                    uint _7848_dummy_parameter;
                    float4 _10740;
                    if (r_depth_tp1.Load(int3(int2(floor(_10435 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7848_dummy_parameter))))), 0)).x > ((exp((_10699 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10740 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10740 = 1.0f.xxxx;
                    }
                    _10739 = _10740;
                }
                else
                {
                    _10739 = 1.0f.xxxx;
                }
                _10738 = _10739;
            }
            bool _4811 = _10676 >= 0.0f;
            bool _4818;
            if (_4811)
            {
                _4818 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4818 = _4811;
            }
            bool _4824;
            if (_4818)
            {
                _4824 = _10681.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4824 = _4818;
            }
            bool _4829;
            if (_4824)
            {
                bool _7872 = all(bool2(_10433.x > 0.0f.xx.x, _10433.y > 0.0f.xx.y));
                bool _7878;
                if (_7872)
                {
                    _7878 = all(bool2(_10433.x < 1.0f.xx.x, _10433.y < 1.0f.xx.y));
                }
                else
                {
                    _7878 = _7872;
                }
                _4829 = _7878;
            }
            else
            {
                _4829 = _4824;
            }
            float4 _10755;
            if (_4829)
            {
                float _10732;
                if (_4811)
                {
                    _10732 = _10676 - _4722;
                }
                else
                {
                    float _10728;
                    _10728 = 2.0f;
                    float _7935;
                    for (int _10727 = 0; _10727 < 24; _10728 = _7935, _10727++)
                    {
                        float _7899 = float(_10727 & 7) * 0.785398185253143310546875f;
                        int _7901 = _10727 >> 3;
                        int _10729;
                        if (_7901 == 0)
                        {
                            _10729 = 16;
                        }
                        else
                        {
                            _10729 = (_7901 == 1) ? 48 : 96;
                        }
                        uint _7951_dummy_parameter;
                        _7935 = min(_10728, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10433 + ((cbFI_MvDepthLaneSizeRcp * float(_10729)) * float2(cos(_7899), sin(_7899))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7951_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10732 = _10728;
                }
                uint _7999_dummy_parameter;
                float4 _10756;
                if (r_depth_tm1.Load(int3(int2(floor(_10433 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7999_dummy_parameter))))), 0)).x > ((exp((_10732 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10273 = _10738;
                    _10273.x = 0.0f;
                    _10756 = _10273;
                }
                else
                {
                    _10756 = _10738;
                }
                _10755 = _10756;
            }
            else
            {
                _10755 = _10738;
            }
            float4 _10768;
            if (_4811)
            {
                float _8025 = (exp(((_10676 - _4722) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _4864 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4870;
                if (_4864)
                {
                    _4870 = _10681.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4870 = _4864;
                }
                bool _4875;
                if (_4870)
                {
                    bool _8030 = all(bool2(_10437.x > 0.0f.xx.x, _10437.y > 0.0f.xx.y));
                    bool _8036;
                    if (_8030)
                    {
                        _8036 = all(bool2(_10437.x < 1.0f.xx.x, _10437.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8036 = _8030;
                    }
                    _4875 = _8036;
                }
                else
                {
                    _4875 = _4870;
                }
                bool _4883;
                if (_4875)
                {
                    uint _8043_dummy_parameter;
                    _4883 = r_depth_tp1.Load(int3(int2(floor(_10437 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8043_dummy_parameter))))), 0)).x > _8025;
                }
                else
                {
                    _4883 = _4875;
                }
                float4 _10766;
                if (_4883)
                {
                    float4 _10276 = _10755;
                    _10276.w = 0.0f;
                    _10766 = _10276;
                }
                else
                {
                    _10766 = _10755;
                }
                bool _4890 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4896;
                if (_4890)
                {
                    _4896 = _10681.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4896 = _4890;
                }
                bool _4901;
                if (_4896)
                {
                    bool _8060 = all(bool2(_10436.x > 0.0f.xx.x, _10436.y > 0.0f.xx.y));
                    bool _8066;
                    if (_8060)
                    {
                        _8066 = all(bool2(_10436.x < 1.0f.xx.x, _10436.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8066 = _8060;
                    }
                    _4901 = _8066;
                }
                else
                {
                    _4901 = _4896;
                }
                bool _4909;
                if (_4901)
                {
                    uint _8073_dummy_parameter;
                    _4909 = r_depth_tm1.Load(int3(int2(floor(_10436 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8073_dummy_parameter))))), 0)).x > _8025;
                }
                else
                {
                    _4909 = _4901;
                }
                float4 _10769;
                if (_4909)
                {
                    float4 _10279 = _10766;
                    _10279.z = 0.0f;
                    _10769 = _10279;
                }
                else
                {
                    _10769 = _10766;
                }
                _10768 = _10769;
            }
            else
            {
                _10768 = _10755;
            }
            float4 _10839;
            if (any(bool4(_10768.x < 1.0f.xxxx.x, _10768.y < 1.0f.xxxx.y, _10768.z < 1.0f.xxxx.z, _10768.w < 1.0f.xxxx.w)))
            {
                float4 _4920 = _10681 * _10768;
                float _4922 = dot(_4920, 1.0f.xxxx);
                float4 _10840;
                if (_4922 > 0.0f)
                {
                    _10840 = _4920 / _4922.xxxx;
                }
                else
                {
                    bool _4933 = _10768.y == 0.0f;
                    bool _4939;
                    if (_4933)
                    {
                        _4939 = _10768.x > 0.0f;
                    }
                    else
                    {
                        _4939 = _4933;
                    }
                    bool _4944;
                    if (_4939)
                    {
                        bool _8090 = all(bool2(_10433.x > 0.0f.xx.x, _10433.y > 0.0f.xx.y));
                        bool _8096;
                        if (_8090)
                        {
                            _8096 = all(bool2(_10433.x < 1.0f.xx.x, _10433.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8096 = _8090;
                        }
                        _4944 = _8096;
                    }
                    else
                    {
                        _4944 = _4939;
                    }
                    float4 _10841;
                    if (_4944)
                    {
                        _10841 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4949 = _10768.x == 0.0f;
                        bool _4955;
                        if (_4949)
                        {
                            _4955 = _10768.y > 0.0f;
                        }
                        else
                        {
                            _4955 = _4949;
                        }
                        bool _4960;
                        if (_4955)
                        {
                            bool _8101 = all(bool2(_10435.x > 0.0f.xx.x, _10435.y > 0.0f.xx.y));
                            bool _8107;
                            if (_8101)
                            {
                                _8107 = all(bool2(_10435.x < 1.0f.xx.x, _10435.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _8107 = _8101;
                            }
                            _4960 = _8107;
                        }
                        else
                        {
                            _4960 = _4955;
                        }
                        bool4 _12557 = _4960.xxxx;
                        _10841 = float4(_12557.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10681.x, _12557.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10681.y, _12557.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10681.z, _12557.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10681.w);
                    }
                    _10840 = _10841;
                }
                _10839 = _10840;
            }
            else
            {
                _10839 = _10681;
            }
            _10838 = _10839;
        }
        else
        {
            _10838 = _10681;
        }
        float4 _11426;
        bool _11446;
        float3 _11560;
        if (((cbFI_pad0 & 32768u) != 0u) && _4679)
        {
            bool _4977 = _10838.x > 0.00999999977648258209228515625f;
            bool _4980 = _10838.y > 0.00999999977648258209228515625f;
            bool _4989 = (_10838.z + _10838.w) > 0.0199999995529651641845703125f;
            bool _4995;
            if (_4989)
            {
                bool _8112 = all(bool2(_10436.x > 0.0f.xx.x, _10436.y > 0.0f.xx.y));
                bool _8118;
                if (_8112)
                {
                    _8118 = all(bool2(_10436.x < 1.0f.xx.x, _10436.y < 1.0f.xx.y));
                }
                else
                {
                    _8118 = _8112;
                }
                _4995 = _8118;
            }
            else
            {
                _4995 = _4989;
            }
            bool _5000;
            if (_4995)
            {
                bool _8123 = all(bool2(_10437.x > 0.0f.xx.x, _10437.y > 0.0f.xx.y));
                bool _8129;
                if (_8123)
                {
                    _8129 = all(bool2(_10437.x < 1.0f.xx.x, _10437.y < 1.0f.xx.y));
                }
                else
                {
                    _8129 = _8123;
                }
                _5000 = _8129;
            }
            else
            {
                _5000 = _4995;
            }
            bool _5007;
            if (_5000)
            {
                float _10849;
                do
                {
                    bool _8212 = all(bool2(_10436.x > 0.0f.xx.x, _10436.y > 0.0f.xx.y));
                    bool _8218;
                    if (_8212)
                    {
                        _8218 = all(bool2(_10436.x < 1.0f.xx.x, _10436.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8218 = _8212;
                    }
                    bool _8149 = !_8218;
                    bool _8156;
                    if (!_8149)
                    {
                        bool _8223 = all(bool2(_10437.x > 0.0f.xx.x, _10437.y > 0.0f.xx.y));
                        bool _8229;
                        if (_8223)
                        {
                            _8229 = all(bool2(_10437.x < 1.0f.xx.x, _10437.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8229 = _8223;
                        }
                        _8156 = !_8229;
                    }
                    else
                    {
                        _8156 = _8149;
                    }
                    if (_8156)
                    {
                        _10849 = 0.0f;
                        break;
                    }
                    uint _8236_dummy_parameter;
                    uint _8252_dummy_parameter;
                    float4 _8177 = mul(float4((float2(_10436.x, 1.0f - _10436.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10436 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8236_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _8179 = _8177.w;
                    if (abs(_8179) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10849 = 0.0f;
                        break;
                    }
                    float _8190 = abs(cbFI_DeviceToViewDepth.y / ((_8177.z / _8179) - cbFI_DeviceToViewDepth.x));
                    float _8193 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10437 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8252_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10849 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8190 - _8193) / max(max(_8190, _8193), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5007 = _10849 < 0.5f;
            }
            else
            {
                _5007 = _5000;
            }
            float4 _10864;
            if (_5007)
            {
                uint _8302_dummy_parameter;
                uint _8333_dummy_parameter;
                float4 _10865;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10436 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8302_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10437 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8333_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10865 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10865 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10864 = _10865;
            }
            else
            {
                _10864 = 1.0f.xxxx;
            }
            bool _5031;
            if (_7083)
            {
                bool _8362 = all(bool2(_10433.x > 0.0f.xx.x, _10433.y > 0.0f.xx.y));
                bool _8368;
                if (_8362)
                {
                    _8368 = all(bool2(_10433.x < 1.0f.xx.x, _10433.y < 1.0f.xx.y));
                }
                else
                {
                    _8368 = _8362;
                }
                _5031 = _8368;
            }
            else
            {
                _5031 = _7083;
            }
            bool _5037;
            if (_7083)
            {
                bool _8373 = all(bool2(_10435.x > 0.0f.xx.x, _10435.y > 0.0f.xx.y));
                bool _8379;
                if (_8373)
                {
                    _8379 = all(bool2(_10435.x < 1.0f.xx.x, _10435.y < 1.0f.xx.y));
                }
                else
                {
                    _8379 = _8373;
                }
                _5037 = _8379;
            }
            else
            {
                _5037 = _7083;
            }
            bool _5043;
            if (_7115)
            {
                bool _8384 = all(bool2(_10436.x > 0.0f.xx.x, _10436.y > 0.0f.xx.y));
                bool _8390;
                if (_8384)
                {
                    _8390 = all(bool2(_10436.x < 1.0f.xx.x, _10436.y < 1.0f.xx.y));
                }
                else
                {
                    _8390 = _8384;
                }
                _5043 = _8390;
            }
            else
            {
                _5043 = _7115;
            }
            bool _5049;
            if (_7115)
            {
                bool _8395 = all(bool2(_10437.x > 0.0f.xx.x, _10437.y > 0.0f.xx.y));
                bool _8401;
                if (_8395)
                {
                    _8401 = all(bool2(_10437.x < 1.0f.xx.x, _10437.y < 1.0f.xx.y));
                }
                else
                {
                    _8401 = _8395;
                }
                _5049 = _8401;
            }
            else
            {
                _5049 = _7115;
            }
            bool _5052 = _5043 != _5049;
            bool _5058;
            if (_5052)
            {
                _5058 = _5031 || _5037;
            }
            else
            {
                _5058 = _5052;
            }
            float4 _10973;
            if (_5058)
            {
                float4 _10306 = _10864;
                _10306.z = 0.0f;
                _10306.w = 0.0f;
                _10973 = _10306;
            }
            else
            {
                _10973 = _10864;
            }
            bool _5065 = _5031 && _4977;
            bool _5068 = _5037 && _4980;
            float4 _11078;
            float3 _11660;
            if (_5065 || _5068)
            {
                float _10968;
                do
                {
                    uint4 _8540 = r_warped_motion_qdata_tp1.Load(int3(_10463, 0));
                    uint _8541 = _8540.x;
                    if (_8541 != 0u)
                    {
                        float _10967;
                        if (_8541 == 0u)
                        {
                            _10967 = -1.0f;
                        }
                        else
                        {
                            _10967 = float((_8541 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10968 = _10967;
                        break;
                    }
                    int _10950;
                    uint _10951;
                    _10951 = _8541;
                    _10950 = -1;
                    uint _10966;
                    for (; _10950 <= 1; _10951 = _10966, _10950++)
                    {
                        _10966 = _10951;
                        for (int _10964 = -1; _10964 <= 1; )
                        {
                            _10966 = max(_10966, r_warped_motion_qdata_tp1.Load(int3(clamp(_10463 + int2(_10964, _10950), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10964++;
                            continue;
                        }
                    }
                    if (_10951 != 0u)
                    {
                        float _10963;
                        if (_10951 == 0u)
                        {
                            _10963 = -1.0f;
                        }
                        else
                        {
                            _10963 = float((_10951 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10968 = _10963;
                        break;
                    }
                    uint _10953;
                    _10953 = 4294967295u;
                    uint _12527;
                    for (int _10952 = 0; _10952 < 8; _10953 = _12527, _10952++)
                    {
                        int _10956 = 0;
                        for (;;)
                        {
                            if (_10956 < 5)
                            {
                                int2 _8491 = _10463 + (_1085[_10952] * _1094[_10956].xx);
                                bool _8494 = any(bool2(_8491.x < int2(0, 0).x, _8491.y < int2(0, 0).y));
                                bool _8502;
                                if (!_8494)
                                {
                                    _8502 = any(bool2(_8491.x >= cbFI_MvDepthLaneSize.x, _8491.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8502 = _8494;
                                }
                                if (_8502)
                                {
                                    _12527 = _10953;
                                    break;
                                }
                                uint4 _8580 = r_warped_motion_qdata_tp1.Load(int3(_8491, 0));
                                uint _8581 = _8580.x;
                                if (_8581 != 0u)
                                {
                                    _12527 = min(_10953, _8581);
                                    break;
                                }
                                _10956++;
                                continue;
                            }
                            else
                            {
                                _12527 = _10953;
                                break;
                            }
                        }
                    }
                    float _10955;
                    if (_10953 == 4294967295u)
                    {
                        _10955 = -1.0f;
                    }
                    else
                    {
                        float _10954;
                        if (_10953 == 0u)
                        {
                            _10954 = -1.0f;
                        }
                        else
                        {
                            _10954 = float((_10953 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10955 = _10954;
                    }
                    _10968 = _10955;
                    break;
                } while(false);
                bool _5076 = _10968 < 0.0f;
                float _10969;
                if (_5076)
                {
                    _10969 = 0.0f;
                }
                else
                {
                    _10969 = _10968 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8602_dummy_parameter;
                uint _8634_dummy_parameter;
                float4 _11006;
                if ((_5076 && _5065) && _5068)
                {
                    uint _8666_dummy_parameter;
                    float _8690 = log((r_depth_tm1.Load(int3(int2(floor(_10433 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8666_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8698_dummy_parameter;
                    float _8722 = log((r_depth_tp1.Load(int3(int2(floor(_10435 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8698_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _11007;
                    if (_8690 > (_8722 + 0.07999999821186065673828125f))
                    {
                        float4 _10310 = _10973;
                        _10310.x = 0.0f;
                        _11007 = _10310;
                    }
                    else
                    {
                        float4 _11008;
                        if (_8722 > (_8690 + 0.07999999821186065673828125f))
                        {
                            float4 _10312 = _10973;
                            _10312.y = 0.0f;
                            _11008 = _10312;
                        }
                        else
                        {
                            _11008 = _10973;
                        }
                        _11007 = _11008;
                    }
                    _11006 = _11007;
                }
                else
                {
                    _11006 = _10973;
                }
                float _5128 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5130 = _10968 >= 0.0f;
                float _10989;
                if (_5130)
                {
                    _10989 = _10968 - _5128;
                }
                else
                {
                    float _10985;
                    if (_5065)
                    {
                        float _10984;
                        _10984 = 2.0f;
                        float _8780;
                        for (int _10983 = 0; _10983 < 24; _10984 = _8780, _10983++)
                        {
                            float _8744 = float(_10983 & 7) * 0.785398185253143310546875f;
                            int _8746 = _10983 >> 3;
                            int _10986;
                            if (_8746 == 0)
                            {
                                _10986 = 16;
                            }
                            else
                            {
                                _10986 = (_8746 == 1) ? 48 : 96;
                            }
                            uint _8796_dummy_parameter;
                            _8780 = min(_10984, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10433 + ((cbFI_MvDepthLaneSizeRcp * float(_10986)) * float2(cos(_8744), sin(_8744))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8796_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10985 = _10984;
                    }
                    else
                    {
                        _10985 = 0.0f;
                    }
                    _10989 = _10985;
                }
                float _10996;
                if (_5130)
                {
                    _10996 = _10968 - _5128;
                }
                else
                {
                    float _10992;
                    if (_5068)
                    {
                        float _10991;
                        _10991 = 2.0f;
                        float _8894;
                        for (int _10990 = 0; _10990 < 24; _10991 = _8894, _10990++)
                        {
                            float _8858 = float(_10990 & 7) * 0.785398185253143310546875f;
                            int _8860 = _10990 >> 3;
                            int _10993;
                            if (_8860 == 0)
                            {
                                _10993 = 16;
                            }
                            else
                            {
                                _10993 = (_8860 == 1) ? 48 : 96;
                            }
                            uint _8926_dummy_parameter;
                            _8894 = min(_10991, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10435 + ((cbFI_MvDepthLaneSizeRcp * float(_10993)) * float2(cos(_8858), sin(_8858))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8926_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10992 = _10991;
                    }
                    else
                    {
                        _10992 = 0.0f;
                    }
                    _10996 = _10992;
                }
                float _10997;
                if (_5065)
                {
                    uint _8958_dummy_parameter;
                    _10997 = r_depth_tm1.Load(int3(int2(floor(_10433 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8958_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10997 = 0.0f;
                }
                float _10998;
                if (_5068)
                {
                    uint _8977_dummy_parameter;
                    _10998 = r_depth_tp1.Load(int3(int2(floor(_10435 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8977_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10998 = 0.0f;
                }
                bool _5185;
                if (_5065)
                {
                    _5185 = _10997 > ((exp((_10989 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5185 = _5065;
                }
                float4 _11014;
                if (_5185)
                {
                    float4 _10314 = _11006;
                    _10314.x = 0.0f;
                    _11014 = _10314;
                }
                else
                {
                    _11014 = _11006;
                }
                bool _5197;
                if (_5068)
                {
                    _5197 = _10998 > ((exp((_10996 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5197 = _5068;
                }
                float4 _11016;
                if (_5197)
                {
                    float4 _10316 = _11014;
                    _10316.y = 0.0f;
                    _11016 = _10316;
                }
                else
                {
                    _11016 = _11014;
                }
                float4 _11079;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5130)
                {
                    bool _5217;
                    if (_5065)
                    {
                        _5217 = _10997 < ((exp((_10989 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5217 = _5065;
                    }
                    float4 _11018;
                    if (_5217)
                    {
                        float4 _10318 = _11016;
                        _10318.x = 0.0f;
                        _11018 = _10318;
                    }
                    else
                    {
                        _11018 = _11016;
                    }
                    bool _5229;
                    if (_5068)
                    {
                        _5229 = _10998 < ((exp((_10996 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5229 = _5068;
                    }
                    float4 _11080;
                    if (_5229)
                    {
                        float4 _10320 = _11018;
                        _10320.y = 0.0f;
                        _11080 = _10320;
                    }
                    else
                    {
                        _11080 = _11018;
                    }
                    _11079 = _11080;
                }
                else
                {
                    _11079 = _11016;
                }
                _11660 = float3(_10969, log((r_depth_tm1.Load(int3(int2(floor(_10433 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8602_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_10435 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8634_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _11078 = _11079;
            }
            else
            {
                _11660 = float3(0.0f, 0.0f, 0.5f);
                _11078 = _10973;
            }
            bool _5240 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4989;
            bool _5246;
            if (_5240)
            {
                _5246 = _5043 || _5049;
            }
            else
            {
                _5246 = _5240;
            }
            float4 _11101;
            if (_5246)
            {
                float _11073;
                do
                {
                    uint4 _9156 = r_warped_motion_qdata_tp1.Load(int3(_10463, 0));
                    uint _9157 = _9156.x;
                    if (_9157 != 0u)
                    {
                        float _11072;
                        if (_9157 == 0u)
                        {
                            _11072 = -1.0f;
                        }
                        else
                        {
                            _11072 = float((_9157 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11073 = _11072;
                        break;
                    }
                    int _11055;
                    uint _11056;
                    _11056 = _9157;
                    _11055 = -1;
                    uint _11071;
                    for (; _11055 <= 1; _11056 = _11071, _11055++)
                    {
                        _11071 = _11056;
                        for (int _11069 = -1; _11069 <= 1; )
                        {
                            _11071 = max(_11071, r_warped_motion_qdata_tp1.Load(int3(clamp(_10463 + int2(_11069, _11055), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11069++;
                            continue;
                        }
                    }
                    if (_11056 != 0u)
                    {
                        float _11068;
                        if (_11056 == 0u)
                        {
                            _11068 = -1.0f;
                        }
                        else
                        {
                            _11068 = float((_11056 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11073 = _11068;
                        break;
                    }
                    uint _11058;
                    _11058 = 4294967295u;
                    uint _12528;
                    for (int _11057 = 0; _11057 < 8; _11058 = _12528, _11057++)
                    {
                        int _11061 = 0;
                        for (;;)
                        {
                            if (_11061 < 5)
                            {
                                int2 _9107 = _10463 + (_1085[_11057] * _1094[_11061].xx);
                                bool _9110 = any(bool2(_9107.x < int2(0, 0).x, _9107.y < int2(0, 0).y));
                                bool _9118;
                                if (!_9110)
                                {
                                    _9118 = any(bool2(_9107.x >= cbFI_MvDepthLaneSize.x, _9107.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _9118 = _9110;
                                }
                                if (_9118)
                                {
                                    _12528 = _11058;
                                    break;
                                }
                                uint4 _9196 = r_warped_motion_qdata_tp1.Load(int3(_9107, 0));
                                uint _9197 = _9196.x;
                                if (_9197 != 0u)
                                {
                                    _12528 = min(_11058, _9197);
                                    break;
                                }
                                _11061++;
                                continue;
                            }
                            else
                            {
                                _12528 = _11058;
                                break;
                            }
                        }
                    }
                    float _11060;
                    if (_11058 == 4294967295u)
                    {
                        _11060 = -1.0f;
                    }
                    else
                    {
                        float _11059;
                        if (_11058 == 0u)
                        {
                            _11059 = -1.0f;
                        }
                        else
                        {
                            _11059 = float((_11058 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11060 = _11059;
                    }
                    _11073 = _11060;
                    break;
                } while(false);
                float4 _11102;
                if (_11073 >= 0.0f)
                {
                    float _9218 = (exp((_11073 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5265;
                    if (_5043)
                    {
                        uint _9225_dummy_parameter;
                        _5265 = r_depth_tm1.Load(int3(int2(floor(_10436 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9225_dummy_parameter))))), 0)).x > _9218;
                    }
                    else
                    {
                        _5265 = _5043;
                    }
                    float4 _11091;
                    if (_5265)
                    {
                        float4 _10322 = _11078;
                        _10322.z = 0.0f;
                        _11091 = _10322;
                    }
                    else
                    {
                        _11091 = _11078;
                    }
                    bool _5277;
                    if (_5049)
                    {
                        uint _9244_dummy_parameter;
                        _5277 = r_depth_tp1.Load(int3(int2(floor(_10437 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9244_dummy_parameter))))), 0)).x > _9218;
                    }
                    else
                    {
                        _5277 = _5049;
                    }
                    float4 _11103;
                    if (_5277)
                    {
                        float4 _10324 = _11091;
                        _10324.w = 0.0f;
                        _11103 = _10324;
                    }
                    else
                    {
                        _11103 = _11091;
                    }
                    _11102 = _11103;
                }
                else
                {
                    _11102 = _11078;
                }
                _11101 = _11102;
            }
            else
            {
                _11101 = _11078;
            }
            bool _5285 = _5031 != _5037;
            bool _5292;
            if (_5285)
            {
                _5292 = _5031 ? _4977 : _4980;
            }
            else
            {
                _5292 = _5285;
            }
            bool _5299;
            if (_5292)
            {
                _5299 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5299 = _5292;
            }
            float4 _11186;
            if (_5299)
            {
                bool2 _5304 = _5031.xx;
                float2 _5305 = float2(_5304.x ? _10433.x : _10435.x, _5304.y ? _10433.y : _10435.y);
                float _11093;
                if (_5031)
                {
                    uint _9263_dummy_parameter;
                    _11093 = r_depth_tm1.Load(int3(int2(floor(_5305 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9263_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9279_dummy_parameter;
                    _11093 = r_depth_tp1.Load(int3(int2(floor(_5305 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9279_dummy_parameter))))), 0)).x;
                }
                float4x4 _11094;
                if (_5031)
                {
                    _11094 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _11094 = cbFI_MotionTP1ToTM1;
                }
                float2 _11095;
                do
                {
                    float _9306 = _5305.x;
                    float _9309 = 1.0f - _5305.y;
                    float4 _9320 = mul(float4((float2(_9306, _9309) * 2.0f) - 1.0f.xx, _11093, 1.0f), _11094);
                    float _9322 = _9320.w;
                    if (!(_9322 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11095 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9335 = ((_9320.xy / _9322.xx) + 1.0f.xx) * 0.5f;
                    _11095 = float2(_9335.x - _9306, _9309 - _9335.y);
                    break;
                } while(false);
                float2 _5335 = float2(cbFI_DisplaySize);
                float4 _11187;
                if (!(length(((_5305 + _11095) - float2(_5304.x ? _10435.x : _10433.x, _5304.y ? _10435.y : _10433.y)) * _5335) <= ((0.100000001490116119384765625f * length(_11095 * _5335)) + 8.0f)))
                {
                    float4 _11188;
                    if (_5031)
                    {
                        float4 _10334 = _11101;
                        _10334.x = 0.0f;
                        _11188 = _10334;
                    }
                    else
                    {
                        float4 _10336 = _11101;
                        _10336.y = 0.0f;
                        _11188 = _10336;
                    }
                    _11187 = _11188;
                }
                else
                {
                    _11187 = _11101;
                }
                _11186 = _11187;
            }
            else
            {
                _11186 = _11101;
            }
            float4 _5360 = _10838 * _11186;
            float _5362 = dot(_5360, 1.0f.xxxx);
            float4 _11427;
            bool _11447;
            if (_5362 > 0.0f)
            {
                _11447 = _10586;
                _11427 = _5360 / _5362.xxxx;
            }
            else
            {
                bool _5373 = any(bool4(_11186.x < 1.0f.xxxx.x, _11186.y < 1.0f.xxxx.y, _11186.z < 1.0f.xxxx.z, _11186.w < 1.0f.xxxx.w));
                if (_5373)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9357;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9357);
                    }
                }
                bool4 _12560 = _5373.xxxx;
                _11447 = _5373 ? true : _10586;
                _11427 = float4(_12560.x ? 0.0f.xxxx.x : _10838.x, _12560.y ? 0.0f.xxxx.y : _10838.y, _12560.z ? 0.0f.xxxx.z : _10838.z, _12560.w ? 0.0f.xxxx.w : _10838.w);
            }
            _11560 = _11660;
            _11446 = _11447;
            _11426 = _11427;
        }
        else
        {
            _11560 = float3(0.0f, 0.0f, 0.5f);
            _11446 = _10586;
            _11426 = _10838;
        }
        uint _5382 = (cbFI_pad0 >> 24u) & 31u;
        uint _5386 = (cbFI_pad0 >> 16u) & 255u;
        bool _5388 = _5382 != 0u;
        bool _5390 = _5386 == 12u;
        bool _5393 = _5386 == 13u;
        float4 _11443;
        if ((_5388 || _5390) || _5393)
        {
            float _11189;
            do
            {
                bool _9441 = all(bool2(_10436.x > 0.0f.xx.x, _10436.y > 0.0f.xx.y));
                bool _9447;
                if (_9441)
                {
                    _9447 = all(bool2(_10436.x < 1.0f.xx.x, _10436.y < 1.0f.xx.y));
                }
                else
                {
                    _9447 = _9441;
                }
                bool _9378 = !_9447;
                bool _9385;
                if (!_9378)
                {
                    bool _9452 = all(bool2(_10437.x > 0.0f.xx.x, _10437.y > 0.0f.xx.y));
                    bool _9458;
                    if (_9452)
                    {
                        _9458 = all(bool2(_10437.x < 1.0f.xx.x, _10437.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9458 = _9452;
                    }
                    _9385 = !_9458;
                }
                else
                {
                    _9385 = _9378;
                }
                if (_9385)
                {
                    _11189 = 0.0f;
                    break;
                }
                uint _9465_dummy_parameter;
                uint _9481_dummy_parameter;
                float4 _9406 = mul(float4((float2(_10436.x, 1.0f - _10436.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10436 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9465_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9408 = _9406.w;
                if (abs(_9408) < 9.9999999747524270787835121154785e-07f)
                {
                    _11189 = 0.0f;
                    break;
                }
                float _9419 = abs(cbFI_DeviceToViewDepth.y / ((_9406.z / _9408) - cbFI_DeviceToViewDepth.x));
                float _9422 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10437 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9481_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _11189 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9419 - _9422) / max(max(_9419, _9422), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9529 = all(bool2(_10437.x > 0.0f.xx.x, _10437.y > 0.0f.xx.y));
            bool _9535;
            if (_9529)
            {
                _9535 = all(bool2(_10437.x < 1.0f.xx.x, _10437.y < 1.0f.xx.y));
            }
            else
            {
                _9535 = _9529;
            }
            float _11190;
            if (_9535)
            {
                uint _9542_dummy_parameter;
                _11190 = length((_6169 + (r_motion_tp1.Load(int3(int2(floor(_10437 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9542_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _11190 = 1000000.0f;
            }
            float _11201;
            if ((_5382 & 1u) != 0u)
            {
                _11201 = _11189;
            }
            else
            {
                _11201 = 1.0f;
            }
            float _11202;
            if ((_5382 & 2u) != 0u)
            {
                _11202 = _11201 * (1.0f - smoothstep(2.0f, 8.0f, _11190));
            }
            else
            {
                _11202 = _11201;
            }
            float _11203;
            if ((_5382 & 4u) != 0u)
            {
                _11203 = _11202 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6890 - _6898) - length(_6874 - _6882))));
            }
            else
            {
                _11203 = _11202;
            }
            float _11437;
            if ((_5382 & 8u) != 0u)
            {
                _11437 = lerp(1.0f, _11203, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6874 - _6882)));
            }
            else
            {
                _11437 = _11203;
            }
            bool _5468 = (_5382 & 16u) != 0u;
            bool _5477;
            if (_5468)
            {
                _5477 = length(_10431 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5477 = _5468;
            }
            float _12562 = _5477 ? 1.0f : _11437;
            bool _5483 = _5388 && _7083;
            bool _5488;
            if (_5483)
            {
                bool _9567 = all(bool2(_10433.x > 0.0f.xx.x, _10433.y > 0.0f.xx.y));
                bool _9573;
                if (_9567)
                {
                    _9573 = all(bool2(_10433.x < 1.0f.xx.x, _10433.y < 1.0f.xx.y));
                }
                else
                {
                    _9573 = _9567;
                }
                _5488 = _9573;
            }
            else
            {
                _5488 = _5483;
            }
            bool _5493;
            if (_5488)
            {
                bool _9578 = all(bool2(_10435.x > 0.0f.xx.x, _10435.y > 0.0f.xx.y));
                bool _9584;
                if (_9578)
                {
                    _9584 = all(bool2(_10435.x < 1.0f.xx.x, _10435.y < 1.0f.xx.y));
                }
                else
                {
                    _9584 = _9578;
                }
                _5493 = _9584;
            }
            else
            {
                _5493 = _5488;
            }
            float4 _11444;
            if (_5493)
            {
                float _5499 = _11426.x + _11426.y;
                float _5508 = (_11426.z + _11426.w) * (1.0f - _12562);
                float _11440;
                if (_5499 > 9.9999997473787516355514526367188e-06f)
                {
                    _11440 = _11426.x / _5499;
                }
                else
                {
                    _11440 = _4349;
                }
                _11444 = float4(_11426.x + (_5508 * _11440), _11426.y + (_5508 * (1.0f - _11440)), _11426.zw * _12562);
            }
            else
            {
                _11444 = _11426;
            }
            _11443 = _11444;
        }
        else
        {
            _11443 = _11426;
        }
        float3 _12330;
        if (_11446)
        {
            float3 _9590 = r_current_interpolation_source.Load(int3(_3721, 0)).xyz;
            float3 _12331;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _7083)
            {
                uint _9597_dummy_parameter;
                float _11551;
                _11551 = r_depth_tm1.Load(int3(int2(floor(_10433 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9597_dummy_parameter))))), 0)).x;
                float _5620;
                for (int _11550 = 0; _11550 < 24; _11551 = _5620, _11550++)
                {
                    float _5592 = float(_11550 & 7) * 0.785398185253143310546875f;
                    int _5594 = _11550 >> 3;
                    int _12381;
                    if (_5594 == 0)
                    {
                        _12381 = 16;
                    }
                    else
                    {
                        _12381 = (_5594 == 1) ? 48 : 96;
                    }
                    uint _9617_dummy_parameter;
                    _5620 = min(_11551, r_depth_tm1.Load(int3(int2(floor(clamp(_10433 + ((cbFI_MvDepthLaneSizeRcp * float(_12381)) * float2(cos(_5592), sin(_5592))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9617_dummy_parameter))))), 0)).x);
                }
                float2 _11552;
                do
                {
                    float _9639 = 1.0f - _10433.y;
                    float4 _9650 = mul(float4((float2(_10433.x, _9639) * 2.0f) - 1.0f.xx, _11551, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9652 = _9650.w;
                    if (!(_9652 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11552 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9665 = ((_9650.xy / _9652.xx) + 1.0f.xx) * 0.5f;
                    _11552 = float2(_9665.x - _10433.x, _9639 - _9665.y);
                    break;
                } while(false);
                float2 _5631 = _10433 + _11552;
                bool _9683 = all(bool2(_5631.x > 0.0f.xx.x, _5631.y > 0.0f.xx.y));
                bool _9689;
                if (_9683)
                {
                    _9689 = all(bool2(_5631.x < 1.0f.xx.x, _5631.y < 1.0f.xx.y));
                }
                else
                {
                    _9689 = _9683;
                }
                float3 _12332;
                if (_9689)
                {
                    float _5637 = abs(cbFI_DeviceToViewDepth.y / (_11551 - cbFI_DeviceToViewDepth.x));
                    uint _9709_dummy_parameter;
                    int2 _9709 = int2(spvTextureSize(r_depth_m2, uint(0), _9709_dummy_parameter));
                    float _5641 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5631 * float2(_9709))), int2(0, 0), _9709 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12337;
                    if (abs(_5641 - _5637) <= (0.20000000298023223876953125f * max(_5641, _5637)))
                    {
                        uint _9743_dummy_parameter;
                        int2 _9743 = int2(spvTextureSize(r_colour_m2, uint(0), _9743_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9766;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9766);
                        }
                        _12337 = r_colour_m2.Load(int3(clamp(int2(floor(_5631 * float2(_9743))), int2(0, 0), _9743 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9776;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9776);
                        }
                        _12337 = _9590;
                    }
                    _12332 = _12337;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9786;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9786);
                    }
                    _12332 = _9590;
                }
                _12331 = _12332;
            }
            else
            {
                _12331 = _9590;
            }
            _12330 = _12331;
        }
        else
        {
            _12330 = (((_6874 * _11443.x) + (_6882 * _11443.y)) + (_6890 * _11443.z)) + (_6898 * _11443.w);
        }
        uint _5669 = cbFI_pad0 & 255u;
        bool _12222;
        float3 _12329;
        if (_5669 != 0u)
        {
            float3 _5674 = r_present_backbuffer.Load(int3(_3721, 0)).xyz;
            float3 _5678 = r_current_interpolation_source.Load(int3(_3721, 0)).xyz;
            float3 _5682 = abs(_5674 - _5678);
            float3 _11555;
            if (_5669 == 2u)
            {
                _11555 = (abs(_5678) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11555 = 0.000244140625f.xxx;
            }
            bool _5698 = any(bool3(_5682.x > _11555.x, _5682.y > _11555.y, _5682.z > _11555.z));
            bool3 _12563 = _5698.xxx;
            _12329 = float3(_12563.x ? _5674.x : _12330.x, _12563.y ? _5674.y : _12330.y, _12563.z ? _5674.z : _12330.z);
            _12222 = _5698;
        }
        else
        {
            _12329 = _12330;
            _12222 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9801;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9801);
        }
        float3 _12312;
        if (_5386 == 1u)
        {
            _12312 = lerp(_6874, _6882, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12313;
            if (_5386 == 2u)
            {
                _12313 = lerp(_6890, _6898, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12314;
                if (_5386 == 3u)
                {
                    _12314 = float(_12222).xxx;
                }
                else
                {
                    float3 _12315;
                    if (_5386 == 4u)
                    {
                        _12315 = float3(((_10431 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12316;
                        if (_5386 == 5u)
                        {
                            _12316 = float3(((_6169 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12317;
                            if (_5386 == 6u)
                            {
                                _12317 = float3(_11443.xy, _11443.z + _11443.w);
                            }
                            else
                            {
                                float3 _12318;
                                if (_5386 == 7u)
                                {
                                    _12318 = r_current_interpolation_source.Load(int3(_3721, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12319;
                                    if (_5386 == 8u)
                                    {
                                        _12319 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4124, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12320;
                                        if (_5390)
                                        {
                                            uint _9823_dummy_parameter;
                                            uint _9855_dummy_parameter;
                                            _12320 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4124 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9823_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4124 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9855_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12321;
                                            if (_5393)
                                            {
                                                _12321 = _6890;
                                            }
                                            else
                                            {
                                                float3 _12322;
                                                if (_5386 == 20u)
                                                {
                                                    _12322 = _6874;
                                                }
                                                else
                                                {
                                                    float3 _12323;
                                                    if (_5386 == 21u)
                                                    {
                                                        _12323 = _6882;
                                                    }
                                                    else
                                                    {
                                                        float3 _12324;
                                                        if (_5386 == 22u)
                                                        {
                                                            _12324 = _6898;
                                                        }
                                                        else
                                                        {
                                                            float3 _12325;
                                                            if (_5386 == 18u)
                                                            {
                                                                _12325 = _11969;
                                                            }
                                                            else
                                                            {
                                                                float3 _12326;
                                                                if (_5386 == 19u)
                                                                {
                                                                    _12326 = _11762;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12565 = (_5386 == 23u).xxx;
                                                                    _12326 = float3(_12565.x ? _11560.x : _12329.x, _12565.y ? _11560.y : _12329.y, _12565.z ? _11560.z : _12329.z);
                                                                }
                                                                _12325 = _12326;
                                                            }
                                                            _12324 = _12325;
                                                        }
                                                        _12323 = _12324;
                                                    }
                                                    _12322 = _12323;
                                                }
                                                _12321 = _12322;
                                            }
                                            _12320 = _12321;
                                        }
                                        _12319 = _12320;
                                    }
                                    _12318 = _12319;
                                }
                                _12317 = _12318;
                            }
                            _12316 = _12317;
                        }
                        _12315 = _12316;
                    }
                    _12314 = _12315;
                }
                _12313 = _12314;
            }
            _12312 = _12313;
        }
        float3 _12311;
        if ((_5386 >= 9u) && (_5386 <= 11u))
        {
            uint _5862 = 64u + uint((_10463.y * cbFI_MvDepthLaneSize.x) + _10463.x);
            uint _5866 = rw_nfru_diagnostics.Load<uint>(_5862 * 4 + 0) & 15u;
            float3 _12342;
            if (_5386 == 10u)
            {
                float3 _12310;
                if ((rw_nfru_diagnostics.Load<uint>(_5862 * 4 + 0) & 32u) != 0u)
                {
                    _12310 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12309;
                    if ((rw_nfru_diagnostics.Load<uint>(_5862 * 4 + 0) & 16u) != 0u)
                    {
                        _12309 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5887 = ((rw_nfru_diagnostics.Load<uint>(_5862 * 4 + 0) & 64u) != 0u).xxx;
                        _12309 = float3(_5887.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5887.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5887.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12310 = _12309;
                }
                _12342 = _12310;
            }
            else
            {
                float3 _12343;
                if (_5386 == 11u)
                {
                    uint _5900 = (rw_nfru_diagnostics.Load<uint>(_5862 * 4 + 0) >> 8u) & 15u;
                    uint _5903 = (rw_nfru_diagnostics.Load<uint>(_5862 * 4 + 0) >> 12u) & 15u;
                    float3 _12302;
                    if ((_5866 == 2u) || (_5866 == 3u))
                    {
                        _12302 = _3434[_5866];
                    }
                    else
                    {
                        bool _5915 = _5900 == 3u;
                        bool _5917 = _5903 == 3u;
                        float3 _12303;
                        if (_5915 && _5917)
                        {
                            _12303 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12304;
                            if (_5915)
                            {
                                _12304 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12305;
                                if (_5917)
                                {
                                    _12305 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12306;
                                    if ((_5900 == 4u) || (_5903 == 4u))
                                    {
                                        _12306 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12307;
                                        if ((_5900 == 1u) || (_5903 == 1u))
                                        {
                                            _12307 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12567 = (_5866 == 1u).xxx;
                                            _12307 = float3(_12567.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12567.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12567.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _12306 = _12307;
                                    }
                                    _12305 = _12306;
                                }
                                _12304 = _12305;
                            }
                            _12303 = _12304;
                        }
                        _12302 = _12303;
                    }
                    _12343 = _12302;
                }
                else
                {
                    _12343 = _3434[min(_5866, 7u)];
                }
                _12342 = _12343;
            }
            _12311 = _12342;
        }
        else
        {
            _12311 = _12312;
        }
        float4 _12346;
        if ((_5386 >= 14u) && (_5386 <= 16u))
        {
            float2 _12344;
            if (_5386 == 14u)
            {
                uint _5973_dummy_parameter;
                uint _5979_dummy_parameter;
                _12344 = r_flow_tm1.Load(int3(clamp(int2(floor(_4124 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5973_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5979_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12345;
                if (_5386 == 16u)
                {
                    uint _9906 = r_warped_flow_qdata_tm1.Load(int3(_4140, 0)).x & 2147483647u;
                    uint _9938 = uint(max((int((_9906 >> 16u) & 15u) - 6), 0));
                    _12345 = ((float2(float((1 - (2 * int((_9906 >> 15u) & 1u))) * int(((_9906 >> uint(7)) & 127u) << _9938)), float((1 - (2 * int((_9906 >> 14u) & 1u))) * int((_9906 & 127u) << _9938))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12345 = _6169 * float2(cbFI_DisplaySize);
                }
                _12344 = _12345;
            }
            uint2 _6012 = uint2(clamp(round(_12344 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6014 = _6012.x;
            uint _6021 = _6012.y;
            _12346 = float4(float(_6014 & 255u), float((_6014 >> 8u) | ((_6021 & 15u) << 4u)), float(_6021 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12347;
            if (_5386 == 17u)
            {
                _12347 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4140, 0)).x != 0u), _4483, 0.0f, 1.0f);
            }
            else
            {
                _12347 = float4(_12311, 1.0f);
            }
            _12346 = _12347;
        }
        rw_output[_3721] = _12346.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6065 = ((uint(_3721.y) * uint(cbFI_DisplaySize.x)) + uint(_3721.x)) * 6u;
            uint _9984 = spvPackHalf2x16(clamp(_6873.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6065 * 4 + 0, (((_9984 & 32767u) >> 4u) | ((((_9984 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6873.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10019 = spvPackHalf2x16(clamp(_6881.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6065 + 1u) * 4 + 0, (((_10019 & 32767u) >> 4u) | ((((_10019 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6881.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10054 = spvPackHalf2x16(clamp(_6889.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6065 + 2u) * 4 + 0, (((_10054 & 32767u) >> 4u) | ((((_10054 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6889.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10089 = spvPackHalf2x16(clamp(_6897.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6065 + 3u) * 4 + 0, (((_10089 & 32767u) >> 4u) | ((((_10089 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6897.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _10116 = r_current_interpolation_source.Load(int3(_3721, 0));
            uint _10130 = spvPackHalf2x16(clamp(_10116.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6065 + 4u) * 4 + 0, (((_10130 & 32767u) >> 4u) | ((((_10130 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10116.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12380;
            if (_12222 || (_5386 != 0u))
            {
                _12380 = 4294967295u;
            }
            else
            {
                uint _10165 = spvPackHalf2x16(clamp(_12346.xy, 0.0f.xx, 65000.0f.xx));
                _12380 = (((_10165 & 32767u) >> 4u) | ((((_10165 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12346.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6065 + 5u) * 4 + 0, _12380);
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
