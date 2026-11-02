static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19113;

static const int2 _1251[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1260[5] = { 2, 4, 7, 11, 16 };
static const float3 _4587[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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

                                           
float spvDet2x2(float a1, float a2, float b1, float b2)
{
    return a1 * b2 - b1 * a2;
}

                                           
float spvDet3x3(float a1, float a2, float a3, float b1, float b2, float b3, float c1, float c2, float c3)
{
    return a1 * spvDet2x2(b2, b3, c2, c3) - b1 * spvDet2x2(a2, a3, c2, c3) + c1 * spvDet2x2(a2, a3, b2, b3);
}

                                                                                       
                                                                                   
float4x4 spvInverse(float4x4 m)
{
    float4x4 adj;	                                                             

                                                                                     
    adj[0][0] =  spvDet3x3(m[1][1], m[1][2], m[1][3], m[2][1], m[2][2], m[2][3], m[3][1], m[3][2], m[3][3]);
    adj[0][1] = -spvDet3x3(m[0][1], m[0][2], m[0][3], m[2][1], m[2][2], m[2][3], m[3][1], m[3][2], m[3][3]);
    adj[0][2] =  spvDet3x3(m[0][1], m[0][2], m[0][3], m[1][1], m[1][2], m[1][3], m[3][1], m[3][2], m[3][3]);
    adj[0][3] = -spvDet3x3(m[0][1], m[0][2], m[0][3], m[1][1], m[1][2], m[1][3], m[2][1], m[2][2], m[2][3]);

    adj[1][0] = -spvDet3x3(m[1][0], m[1][2], m[1][3], m[2][0], m[2][2], m[2][3], m[3][0], m[3][2], m[3][3]);
    adj[1][1] =  spvDet3x3(m[0][0], m[0][2], m[0][3], m[2][0], m[2][2], m[2][3], m[3][0], m[3][2], m[3][3]);
    adj[1][2] = -spvDet3x3(m[0][0], m[0][2], m[0][3], m[1][0], m[1][2], m[1][3], m[3][0], m[3][2], m[3][3]);
    adj[1][3] =  spvDet3x3(m[0][0], m[0][2], m[0][3], m[1][0], m[1][2], m[1][3], m[2][0], m[2][2], m[2][3]);

    adj[2][0] =  spvDet3x3(m[1][0], m[1][1], m[1][3], m[2][0], m[2][1], m[2][3], m[3][0], m[3][1], m[3][3]);
    adj[2][1] = -spvDet3x3(m[0][0], m[0][1], m[0][3], m[2][0], m[2][1], m[2][3], m[3][0], m[3][1], m[3][3]);
    adj[2][2] =  spvDet3x3(m[0][0], m[0][1], m[0][3], m[1][0], m[1][1], m[1][3], m[3][0], m[3][1], m[3][3]);
    adj[2][3] = -spvDet3x3(m[0][0], m[0][1], m[0][3], m[1][0], m[1][1], m[1][3], m[2][0], m[2][1], m[2][3]);

    adj[3][0] = -spvDet3x3(m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2], m[3][0], m[3][1], m[3][2]);
    adj[3][1] =  spvDet3x3(m[0][0], m[0][1], m[0][2], m[2][0], m[2][1], m[2][2], m[3][0], m[3][1], m[3][2]);
    adj[3][2] = -spvDet3x3(m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[3][0], m[3][1], m[3][2]);
    adj[3][3] =  spvDet3x3(m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2]);

                                                                                    
    float det = (adj[0][0] * m[0][0]) + (adj[0][1] * m[1][0]) + (adj[0][2] * m[2][0]) + (adj[0][3] * m[3][0]);

                                                              
                                                                               
    return (det != 0.0f) ? (adj * (1.0f / det)) : m;
}

void comp_main()
{
    int2 _4905 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4905.x >= cbFI_DisplaySize.x, _4905.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4905] = float4(r_present_backbuffer.Load(int3(_4905, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4905] = float4(r_current_interpolation_source.Load(int3(_4905, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7795 = cbFI_DisplaySize - int2(1, 1);
                int2 _7796 = clamp(_4905, int2(0, 0), _7795);
                uint _7806 = uint((_7796.y * cbFI_DisplaySize.x) + _7796.x) * 2u;
                uint _7809 = rw_nfru_select.Load<uint>(_7806 * 4 + 0);
                float2 _7810 = spvUnpackHalf2x16(_7809);
                uint _7814 = rw_nfru_select.Load<uint>((_7806 + 1u) * 4 + 0);
                float2 _7815 = spvUnpackHalf2x16(_7814);
                float _7816 = _7810.x;
                float _7818 = _7815.x;
                if (_7815.y > 1.5f)
                {
                    rw_output[_4905] = float4(_7816, _7810.y, _7818, 1.0f).xyz;
                    break;
                }
                int _22442;
                float _22443;
                float3 _22444;
                float _22445;
                float _22446;
                _22446 = 0.0f;
                _22445 = 0.0f;
                _22444 = 0.0f.xxx;
                _22443 = 0.0f;
                _22442 = -2;
                float3 _22449;
                float _22450;
                float _22451;
                float _22452;
                for (; _22442 <= 2; _22446 = _22452, _22445 = _22451, _22444 = _22449, _22443 = _22450, _22442++)
                {
                    _22452 = _22446;
                    _22451 = _22445;
                    _22450 = _22443;
                    _22449 = _22444;
                    for (int _22447 = -2; _22447 <= 2; )
                    {
                        float _7712 = float((_22447 * _22447) + (_22442 * _22442));
                        float _7717 = exp(_7712 * (-0.319999992847442626953125f));
                        int2 _7722 = int2(_22447, _22442);
                        int2 _7832 = clamp(_4905 + (_7722 * int2(2, 2)), int2(0, 0), _7795);
                        uint _7842 = uint((_7832.y * cbFI_DisplaySize.x) + _7832.x) * 2u;
                        float _7739 = exp(_7712 * (-0.5f));
                        int2 _7864 = clamp(_4905 + (_7722 * int2(6, 6)), int2(0, 0), _7795);
                        _22452 += _7739;
                        _22451 += (_7739 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7864.y * cbFI_DisplaySize.x) + _7864.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _22450 += _7717;
                        _22449 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7842 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7842 + 1u) * 4 + 0)).x, _19113).xyz * _7717);
                        _22447++;
                        continue;
                    }
                }
                float3 _7769 = _22444 / _22443.xxx;
                rw_output[_4905] = float4(_7769 + ((float4(_7816, _7810.y, _7818, _7815.y).xyz - _7769) * clamp(_22445 / _22446, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5417 = (float2(_4905) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5419 = float2(cbFI_MvDepthLaneSize);
        int2 _5428 = int2(floor(_5417 * _5419));
        int2 _5433 = int2(floor(_5417 * float2(cbFI_FlowLaneSize)));
        float4 _7935 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5417 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7941 = r_warped_filled_flow_tm1.Load(int3(_5433, 0)).xy;
        float2 _7947 = r_warped_filled_motion_tp1.Load(int3(_5428, 0)).xy;
        bool _7969 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19114;
        if (_7969)
        {
            float _7982 = ((2.0f * _5417.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19114 = float2(atan(_7982) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5417.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7982 * _7982))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19114 = _5417;
        }
        bool _5454 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19135;
        bool _19277;
        int2 _19358;
        float3 _21608;
        if (_5454)
        {
            float _19116;
            float _19118;
            _19118 = 2.0f;
            _19116 = -1.0f;
            uint _5004[9];
            float _22453;
            float _22456;
            for (int _19115 = 0; _19115 < 9; _19118 = _22456, _19116 = _22453, _19115++)
            {
                _5004[_19115] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5428 + int2((_19115 % 3) - 1, (_19115 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_5004[_19115] != 0u)
                {
                    float _22437;
                    if (_5004[_19115] == 0u)
                    {
                        _22437 = -1.0f;
                    }
                    else
                    {
                        _22437 = float((_5004[_19115] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _22456 = min(_19118, _22437);
                    _22453 = max(_19116, _22437);
                }
                else
                {
                    _22456 = _19118;
                    _22453 = _19116;
                }
            }
            float _5500 = float(_19116 >= 0.0f);
            float3 _18681 = 0.0f.xxx;
            _18681.y = _5500;
            float2 _19136;
            bool _19278;
            int2 _19359;
            float3 _21609;
            if ((_19116 - _19118) > 0.0199999995529651641845703125f)
            {
                float _19124;
                int2 _19125;
                float2 _19126;
                int2 _19128;
                float2 _19134;
                _19134 = _7947;
                _19128 = _5428;
                _19126 = _7947;
                _19125 = _5428;
                _19124 = -1.0f;
                float _22461;
                int2 _22465;
                float2 _22476;
                int2 _22487;
                float2 _22520;
                float _22837;
                int _19123 = 0;
                float _22418 = 1000000000.0f;
                for (; _19123 < 9; _22418 = _22837, _19134 = _22520, _19128 = _22487, _19126 = _22476, _19125 = _22465, _19124 = _22461, _19123++)
                {
                    if (_5004[_19123] == 0u)
                    {
                        _22837 = _22418;
                        _22520 = _19134;
                        _22487 = _19128;
                        _22476 = _19126;
                        _22465 = _19125;
                        _22461 = _19124;
                        continue;
                    }
                    int2 _5535 = clamp(_5428 + int2((_19123 % 3) - 1, (_19123 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8057 = _5004[_19123] & 2147483647u;
                    uint _8089 = uint(max((int((_8057 >> 16u) & 15u) - 6), 0));
                    float2 _5541 = (float2(float((1 - (2 * int((_8057 >> 15u) & 1u))) * int(((_8057 >> uint(7)) & 127u) << _8089)), float((1 - (2 * int((_8057 >> 14u) & 1u))) * int((_8057 & 127u) << _8089))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _22404;
                    if (_5004[_19123] == 0u)
                    {
                        _22404 = -1.0f;
                    }
                    else
                    {
                        _22404 = float((_5004[_19123] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5546 = _22404 - 0.100000001490116119384765625f;
                    float2 _22405;
                    if (_7969)
                    {
                        float2 _8166 = clamp((((_19114 + (_5541 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8169 = tan(_8166.x);
                        _22405 = (float2(_8169 / cbFI_DeviceToViewDepth.z, (tan(_8166.y) * sqrt(1.0f + (_8169 * _8169))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _22405 = _19114 + (_5541 * cbFI_Timestep);
                    }
                    float _5553 = cbFI_Timestep - 1.0f;
                    float2 _22406;
                    if (_7969)
                    {
                        float2 _8237 = clamp((((_19114 + (_5541 * _5553)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8240 = tan(_8237.x);
                        _22406 = (float2(_8240 / cbFI_DeviceToViewDepth.z, (tan(_8237.y) * sqrt(1.0f + (_8240 * _8240))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _22406 = _19114 + (_5541 * _5553);
                    }
                    bool _8273 = all(bool2(_22405.x > 0.0f.xx.x, _22405.y > 0.0f.xx.y));
                    bool _8279;
                    if (_8273)
                    {
                        _8279 = all(bool2(_22405.x < 1.0f.xx.x, _22405.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8279 = _8273;
                    }
                    float _22409;
                    if (_8279)
                    {
                        uint _8286_dummy_parameter;
                        _22409 = max((_5546 - (log(((r_depth_tm1.Load(int3(int2(floor(_22405 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8286_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _22409 = 0.0f;
                    }
                    bool _8316 = all(bool2(_22406.x > 0.0f.xx.x, _22406.y > 0.0f.xx.y));
                    bool _8322;
                    if (_8316)
                    {
                        _8322 = all(bool2(_22406.x < 1.0f.xx.x, _22406.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8322 = _8316;
                    }
                    float _22410;
                    if (_8322)
                    {
                        uint _8329_dummy_parameter;
                        _22410 = _22409 + max((_5546 - (log(((r_depth_tp1.Load(int3(int2(floor(_22406 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8329_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _22410 = _22409;
                    }
                    float _22462;
                    int2 _22466;
                    float2 _22477;
                    int2 _22488;
                    float2 _22521;
                    float _22838;
                    if (_22410 == 0.0f)
                    {
                        bool _5588 = _5546 > _19124;
                        bool2 _22846 = _5588.xx;
                        _22838 = _22418;
                        _22521 = float2(_22846.x ? _5541.x : _19134.x, _22846.y ? _5541.y : _19134.y);
                        _22488 = int2(_22846.x ? _5535.x : _19128.x, _22846.y ? _5535.y : _19128.y);
                        _22477 = _19126;
                        _22466 = _19125;
                        _22462 = _5588 ? _5546 : _19124;
                    }
                    else
                    {
                        bool _5597 = _22410 < _22418;
                        bool2 _22842 = _5597.xx;
                        _22838 = _5597 ? _22410 : _22418;
                        _22521 = _19134;
                        _22488 = _19128;
                        _22477 = float2(_22842.x ? _5541.x : _19126.x, _22842.y ? _5541.y : _19126.y);
                        _22466 = int2(_22842.x ? _5535.x : _19125.x, _22842.y ? _5535.y : _19125.y);
                        _22462 = _19124;
                    }
                    _22837 = _22838;
                    _22520 = _22521;
                    _22487 = _22488;
                    _22476 = _22477;
                    _22465 = _22466;
                    _22461 = _22462;
                }
                bool _5609 = _19124 < 0.0f;
                bool2 _22852 = _5609.xx;
                int2 _22855 = int2(_22852.x ? _19125.x : _19128.x, _22852.y ? _19125.y : _19128.y);
                _21609 = float3(1.0f, _5500, float(any(bool2(_22855.x != _5428.x, _22855.y != _5428.y))));
                _19359 = _22855;
                _19278 = _5609 ? false : true;
                _19136 = float2(_22852.x ? _19126.x : _19134.x, _22852.y ? _19126.y : _19134.y);
            }
            else
            {
                _21609 = _18681;
                _19359 = _5428;
                _19278 = false;
                _19136 = _7947;
            }
            _21608 = _21609;
            _19358 = _19359;
            _19277 = _19278;
            _19135 = _19136;
        }
        else
        {
            _21608 = 0.0f.xxx;
            _19358 = _5428;
            _19277 = false;
            _19135 = _7947;
        }
        float2 _19137;
        if (_7969)
        {
            float2 _8394 = clamp((((_19114 + (_19135 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8397 = tan(_8394.x);
            _19137 = (float2(_8397 / cbFI_DeviceToViewDepth.z, (tan(_8394.y) * sqrt(1.0f + (_8397 * _8397))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19137 = _19114 + (_19135 * cbFI_Timestep);
        }
        float _5632 = cbFI_Timestep - 1.0f;
        float2 _19139;
        if (_7969)
        {
            float2 _8465 = clamp((((_19114 + (_19135 * _5632)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8468 = tan(_8465.x);
            _19139 = (float2(_8468 / cbFI_DeviceToViewDepth.z, (tan(_8465.y) * sqrt(1.0f + (_8468 * _8468))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19139 = _19114 + (_19135 * _5632);
        }
        float _5637 = -cbFI_Timestep;
        float2 _19140;
        if (_7969)
        {
            float2 _8536 = clamp((((_19114 + (_7941 * _5637)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8539 = tan(_8536.x);
            _19140 = (float2(_8539 / cbFI_DeviceToViewDepth.z, (tan(_8536.y) * sqrt(1.0f + (_8539 * _8539))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19140 = _19114 + (_7941 * _5637);
        }
        float _5642 = 1.0f - cbFI_Timestep;
        float2 _19141;
        if (_7969)
        {
            float2 _8607 = clamp((((_19114 + (_7941 * _5642)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8610 = tan(_8607.x);
            _19141 = (float2(_8610 / cbFI_DeviceToViewDepth.z, (tan(_8607.y) * sqrt(1.0f + (_8610 * _8610))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19141 = _19114 + (_7941 * _5642);
        }
        float4 _8645 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19137, 0.0f);
        float3 _8646 = _8645.xyz;
        float4 _8653 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19139, 0.0f);
        float3 _8654 = _8653.xyz;
        float4 _8661 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19140, 0.0f);
        float3 _8662 = _8661.xyz;
        float4 _8669 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19141, 0.0f);
        float3 _8670 = _8669.xyz;
        float4 _8684 = exp(_7935 - max(max(max(_7935.x, _7935.y), _7935.z), _7935.w).xxxx);
        float4 _8691 = _8684 / (dot(_8684, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5658 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19348;
        float _20656;
        if (_5658)
        {
            float2 _5664 = 0.5f.xx / _5419;
            float _5667 = _5664.x;
            float _5668 = -_5667;
            float _5670 = _5664.y;
            float _5671 = -_5670;
            float2 _5673 = _5417 + float2(_5668, _5671);
            float2 _5675 = float2(cbFI_DisplaySize);
            bool _19158;
            do
            {
                bool _8771 = all(bool2(_5673.x > 0.0f.xx.x, _5673.y > 0.0f.xx.y));
                bool _8777;
                if (_8771)
                {
                    _8777 = all(bool2(_5673.x < 1.0f.xx.x, _5673.y < 1.0f.xx.y));
                }
                else
                {
                    _8777 = _8771;
                }
                if (!_8777)
                {
                    _19158 = false;
                    break;
                }
                uint _8784_dummy_parameter;
                float4x4 _19156;
                do
                {
                    float4x4 _8798;
                    bool _19155;
                    do
                    {
                        _8798 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19155 = false;
                            break;
                        }
                        uint _8832 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8832 + 32u) * 4 + 0) != 1u)
                        {
                            _19155 = false;
                            break;
                        }
                        uint _19152;
                        _19152 = 0u;
                        for (; _19152 < 4u; _19152++)
                        {
                            for (uint _19153 = 0u; _19153 < 4u; )
                            {
                                _8798[_19152][_19153] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8832 + (_19152 * 4u)) + _19153) * 4 + 0));
                                _19153++;
                                continue;
                            }
                        }
                        _19155 = true;
                        break;
                    } while(false);
                    if (_19155)
                    {
                        _19156 = _8798;
                        break;
                    }
                    _19156 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19157;
                do
                {
                    float _8909 = _5673.x;
                    float _8912 = 1.0f - _5673.y;
                    float4 _8923 = mul(float4((float2(_8909, _8912) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5673 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8784_dummy_parameter))))), 0)).x, 1.0f), _19156);
                    float _8925 = _8923.w;
                    if (!(_8925 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19157 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8938 = ((_8923.xy / _8925.xx) + 1.0f.xx) * 0.5f;
                    _19157 = float2(_8938.x - _8909, _8912 - _8938.y);
                    break;
                } while(false);
                float2 _8735 = abs(_19157);
                if (any(bool2(_8735.x > 100000.0f.xx.x, _8735.y > 100000.0f.xx.y)))
                {
                    _19158 = false;
                    break;
                }
                float _8743 = length(_19157 * _5675);
                uint _8958_dummy_parameter;
                bool _8757 = _8743 > ((8.0f * _5675.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8764;
                if (_8757)
                {
                    _8764 = length((r_motion_tp1.Load(int3(int2(floor(_5673 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8958_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5675) < (0.20000000298023223876953125f * _8743);
                }
                else
                {
                    _8764 = _8757;
                }
                _19158 = _8764;
                break;
            } while(false);
            float2 _5685 = _5417 + float2(_5667, _5671);
            bool _19165;
            do
            {
                bool _9044 = all(bool2(_5685.x > 0.0f.xx.x, _5685.y > 0.0f.xx.y));
                bool _9050;
                if (_9044)
                {
                    _9050 = all(bool2(_5685.x < 1.0f.xx.x, _5685.y < 1.0f.xx.y));
                }
                else
                {
                    _9050 = _9044;
                }
                if (!_9050)
                {
                    _19165 = false;
                    break;
                }
                uint _9057_dummy_parameter;
                float4x4 _19163;
                do
                {
                    float4x4 _9071;
                    bool _19162;
                    do
                    {
                        _9071 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19162 = false;
                            break;
                        }
                        uint _9105 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9105 + 32u) * 4 + 0) != 1u)
                        {
                            _19162 = false;
                            break;
                        }
                        uint _19159;
                        _19159 = 0u;
                        for (; _19159 < 4u; _19159++)
                        {
                            for (uint _19160 = 0u; _19160 < 4u; )
                            {
                                _9071[_19159][_19160] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9105 + (_19159 * 4u)) + _19160) * 4 + 0));
                                _19160++;
                                continue;
                            }
                        }
                        _19162 = true;
                        break;
                    } while(false);
                    if (_19162)
                    {
                        _19163 = _9071;
                        break;
                    }
                    _19163 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19164;
                do
                {
                    float _9182 = _5685.x;
                    float _9185 = 1.0f - _5685.y;
                    float4 _9196 = mul(float4((float2(_9182, _9185) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5685 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9057_dummy_parameter))))), 0)).x, 1.0f), _19163);
                    float _9198 = _9196.w;
                    if (!(_9198 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19164 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9211 = ((_9196.xy / _9198.xx) + 1.0f.xx) * 0.5f;
                    _19164 = float2(_9211.x - _9182, _9185 - _9211.y);
                    break;
                } while(false);
                float2 _9008 = abs(_19164);
                if (any(bool2(_9008.x > 100000.0f.xx.x, _9008.y > 100000.0f.xx.y)))
                {
                    _19165 = false;
                    break;
                }
                float _9016 = length(_19164 * _5675);
                uint _9231_dummy_parameter;
                bool _9030 = _9016 > ((8.0f * _5675.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9037;
                if (_9030)
                {
                    _9037 = length((r_motion_tp1.Load(int3(int2(floor(_5685 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9231_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5675) < (0.20000000298023223876953125f * _9016);
                }
                else
                {
                    _9037 = _9030;
                }
                _19165 = _9037;
                break;
            } while(false);
            float2 _5698 = _5417 + float2(_5668, _5670);
            bool _19172;
            do
            {
                bool _9317 = all(bool2(_5698.x > 0.0f.xx.x, _5698.y > 0.0f.xx.y));
                bool _9323;
                if (_9317)
                {
                    _9323 = all(bool2(_5698.x < 1.0f.xx.x, _5698.y < 1.0f.xx.y));
                }
                else
                {
                    _9323 = _9317;
                }
                if (!_9323)
                {
                    _19172 = false;
                    break;
                }
                uint _9330_dummy_parameter;
                float4x4 _19170;
                do
                {
                    float4x4 _9344;
                    bool _19169;
                    do
                    {
                        _9344 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19169 = false;
                            break;
                        }
                        uint _9378 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9378 + 32u) * 4 + 0) != 1u)
                        {
                            _19169 = false;
                            break;
                        }
                        uint _19166;
                        _19166 = 0u;
                        for (; _19166 < 4u; _19166++)
                        {
                            for (uint _19167 = 0u; _19167 < 4u; )
                            {
                                _9344[_19166][_19167] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9378 + (_19166 * 4u)) + _19167) * 4 + 0));
                                _19167++;
                                continue;
                            }
                        }
                        _19169 = true;
                        break;
                    } while(false);
                    if (_19169)
                    {
                        _19170 = _9344;
                        break;
                    }
                    _19170 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19171;
                do
                {
                    float _9455 = _5698.x;
                    float _9458 = 1.0f - _5698.y;
                    float4 _9469 = mul(float4((float2(_9455, _9458) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5698 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9330_dummy_parameter))))), 0)).x, 1.0f), _19170);
                    float _9471 = _9469.w;
                    if (!(_9471 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19171 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9484 = ((_9469.xy / _9471.xx) + 1.0f.xx) * 0.5f;
                    _19171 = float2(_9484.x - _9455, _9458 - _9484.y);
                    break;
                } while(false);
                float2 _9281 = abs(_19171);
                if (any(bool2(_9281.x > 100000.0f.xx.x, _9281.y > 100000.0f.xx.y)))
                {
                    _19172 = false;
                    break;
                }
                float _9289 = length(_19171 * _5675);
                uint _9504_dummy_parameter;
                bool _9303 = _9289 > ((8.0f * _5675.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9310;
                if (_9303)
                {
                    _9310 = length((r_motion_tp1.Load(int3(int2(floor(_5698 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9504_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5675) < (0.20000000298023223876953125f * _9289);
                }
                else
                {
                    _9310 = _9303;
                }
                _19172 = _9310;
                break;
            } while(false);
            float2 _5710 = _5417 + _5664;
            bool _19179;
            do
            {
                bool _9590 = all(bool2(_5710.x > 0.0f.xx.x, _5710.y > 0.0f.xx.y));
                bool _9596;
                if (_9590)
                {
                    _9596 = all(bool2(_5710.x < 1.0f.xx.x, _5710.y < 1.0f.xx.y));
                }
                else
                {
                    _9596 = _9590;
                }
                if (!_9596)
                {
                    _19179 = false;
                    break;
                }
                uint _9603_dummy_parameter;
                float4x4 _19177;
                do
                {
                    float4x4 _9617;
                    bool _19176;
                    do
                    {
                        _9617 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19176 = false;
                            break;
                        }
                        uint _9651 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9651 + 32u) * 4 + 0) != 1u)
                        {
                            _19176 = false;
                            break;
                        }
                        uint _19173;
                        _19173 = 0u;
                        for (; _19173 < 4u; _19173++)
                        {
                            for (uint _19174 = 0u; _19174 < 4u; )
                            {
                                _9617[_19173][_19174] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9651 + (_19173 * 4u)) + _19174) * 4 + 0));
                                _19174++;
                                continue;
                            }
                        }
                        _19176 = true;
                        break;
                    } while(false);
                    if (_19176)
                    {
                        _19177 = _9617;
                        break;
                    }
                    _19177 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19178;
                do
                {
                    float _9728 = _5710.x;
                    float _9731 = 1.0f - _5710.y;
                    float4 _9742 = mul(float4((float2(_9728, _9731) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5710 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9603_dummy_parameter))))), 0)).x, 1.0f), _19177);
                    float _9744 = _9742.w;
                    if (!(_9744 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19178 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9757 = ((_9742.xy / _9744.xx) + 1.0f.xx) * 0.5f;
                    _19178 = float2(_9757.x - _9728, _9731 - _9757.y);
                    break;
                } while(false);
                float2 _9554 = abs(_19178);
                if (any(bool2(_9554.x > 100000.0f.xx.x, _9554.y > 100000.0f.xx.y)))
                {
                    _19179 = false;
                    break;
                }
                float _9562 = length(_19178 * _5675);
                uint _9777_dummy_parameter;
                bool _9576 = _9562 > ((8.0f * _5675.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9583;
                if (_9576)
                {
                    _9583 = length((r_motion_tp1.Load(int3(int2(floor(_5710 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9777_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5675) < (0.20000000298023223876953125f * _9562);
                }
                else
                {
                    _9583 = _9576;
                }
                _19179 = _9583;
                break;
            } while(false);
            float _5716 = 0.25f * (((float(_19158) + float(_19165)) + float(_19172)) + float(_19179));
            float4 _19349;
            if (_5716 < 1.0f)
            {
                bool _19186;
                do
                {
                    bool _9863 = all(bool2(_19137.x > 0.0f.xx.x, _19137.y > 0.0f.xx.y));
                    bool _9869;
                    if (_9863)
                    {
                        _9869 = all(bool2(_19137.x < 1.0f.xx.x, _19137.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9869 = _9863;
                    }
                    if (!_9869)
                    {
                        _19186 = false;
                        break;
                    }
                    uint _9876_dummy_parameter;
                    float4x4 _19184;
                    do
                    {
                        float4x4 _9890;
                        bool _19183;
                        do
                        {
                            _9890 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19183 = false;
                                break;
                            }
                            uint _9924 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9924 + 32u) * 4 + 0) != 1u)
                            {
                                _19183 = false;
                                break;
                            }
                            uint _19180;
                            _19180 = 0u;
                            for (; _19180 < 4u; _19180++)
                            {
                                for (uint _19181 = 0u; _19181 < 4u; )
                                {
                                    _9890[_19180][_19181] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9924 + (_19180 * 4u)) + _19181) * 4 + 0));
                                    _19181++;
                                    continue;
                                }
                            }
                            _19183 = true;
                            break;
                        } while(false);
                        if (_19183)
                        {
                            _19184 = _9890;
                            break;
                        }
                        _19184 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19185;
                    do
                    {
                        float _10004 = 1.0f - _19137.y;
                        float4 _10015 = mul(float4((float2(_19137.x, _10004) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19137 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9876_dummy_parameter))))), 0)).x, 1.0f), _19184);
                        float _10017 = _10015.w;
                        if (!(_10017 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19185 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10030 = ((_10015.xy / _10017.xx) + 1.0f.xx) * 0.5f;
                        _19185 = float2(_10030.x - _19137.x, _10004 - _10030.y);
                        break;
                    } while(false);
                    float2 _9827 = abs(_19185);
                    if (any(bool2(_9827.x > 100000.0f.xx.x, _9827.y > 100000.0f.xx.y)))
                    {
                        _19186 = false;
                        break;
                    }
                    float _9835 = length(_19185 * _5675);
                    uint _10050_dummy_parameter;
                    bool _9849 = _9835 > ((8.0f * _5675.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9856;
                    if (_9849)
                    {
                        _9856 = length((r_motion_tp1.Load(int3(int2(floor(_19137 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10050_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5675) < (0.20000000298023223876953125f * _9835);
                    }
                    else
                    {
                        _9856 = _9849;
                    }
                    _19186 = _9856;
                    break;
                } while(false);
                bool _19193;
                do
                {
                    bool _10136 = all(bool2(_19139.x > 0.0f.xx.x, _19139.y > 0.0f.xx.y));
                    bool _10142;
                    if (_10136)
                    {
                        _10142 = all(bool2(_19139.x < 1.0f.xx.x, _19139.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10142 = _10136;
                    }
                    if (!_10142)
                    {
                        _19193 = false;
                        break;
                    }
                    uint _10149_dummy_parameter;
                    float4x4 _19191;
                    do
                    {
                        float4x4 _10163;
                        bool _19190;
                        do
                        {
                            _10163 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19190 = false;
                                break;
                            }
                            uint _10197 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10197 + 32u) * 4 + 0) != 1u)
                            {
                                _19190 = false;
                                break;
                            }
                            uint _19187;
                            _19187 = 0u;
                            for (; _19187 < 4u; _19187++)
                            {
                                for (uint _19188 = 0u; _19188 < 4u; )
                                {
                                    _10163[_19187][_19188] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10197 + (_19187 * 4u)) + _19188) * 4 + 0));
                                    _19188++;
                                    continue;
                                }
                            }
                            _19190 = true;
                            break;
                        } while(false);
                        if (_19190)
                        {
                            _19191 = _10163;
                            break;
                        }
                        _19191 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19192;
                    do
                    {
                        float _10277 = 1.0f - _19139.y;
                        float4 _10288 = mul(float4((float2(_19139.x, _10277) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19139 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10149_dummy_parameter))))), 0)).x, 1.0f), _19191);
                        float _10290 = _10288.w;
                        if (!(_10290 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19192 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10303 = ((_10288.xy / _10290.xx) + 1.0f.xx) * 0.5f;
                        _19192 = float2(_10303.x - _19139.x, _10277 - _10303.y);
                        break;
                    } while(false);
                    float2 _10100 = abs(_19192);
                    if (any(bool2(_10100.x > 100000.0f.xx.x, _10100.y > 100000.0f.xx.y)))
                    {
                        _19193 = false;
                        break;
                    }
                    float _10108 = length(_19192 * _5675);
                    uint _10323_dummy_parameter;
                    bool _10122 = _10108 > ((8.0f * _5675.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10129;
                    if (_10122)
                    {
                        _10129 = length((r_motion_tp1.Load(int3(int2(floor(_19139 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10323_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5675) < (0.20000000298023223876953125f * _10108);
                    }
                    else
                    {
                        _10129 = _10122;
                    }
                    _19193 = _10129;
                    break;
                } while(false);
                bool _19200;
                do
                {
                    bool _10409 = all(bool2(_19140.x > 0.0f.xx.x, _19140.y > 0.0f.xx.y));
                    bool _10415;
                    if (_10409)
                    {
                        _10415 = all(bool2(_19140.x < 1.0f.xx.x, _19140.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10415 = _10409;
                    }
                    if (!_10415)
                    {
                        _19200 = false;
                        break;
                    }
                    uint _10422_dummy_parameter;
                    float4x4 _19198;
                    do
                    {
                        float4x4 _10436;
                        bool _19197;
                        do
                        {
                            _10436 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19197 = false;
                                break;
                            }
                            uint _10470 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10470 + 32u) * 4 + 0) != 1u)
                            {
                                _19197 = false;
                                break;
                            }
                            uint _19194;
                            _19194 = 0u;
                            for (; _19194 < 4u; _19194++)
                            {
                                for (uint _19195 = 0u; _19195 < 4u; )
                                {
                                    _10436[_19194][_19195] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10470 + (_19194 * 4u)) + _19195) * 4 + 0));
                                    _19195++;
                                    continue;
                                }
                            }
                            _19197 = true;
                            break;
                        } while(false);
                        if (_19197)
                        {
                            _19198 = _10436;
                            break;
                        }
                        _19198 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19199;
                    do
                    {
                        float _10550 = 1.0f - _19140.y;
                        float4 _10561 = mul(float4((float2(_19140.x, _10550) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19140 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10422_dummy_parameter))))), 0)).x, 1.0f), _19198);
                        float _10563 = _10561.w;
                        if (!(_10563 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19199 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10576 = ((_10561.xy / _10563.xx) + 1.0f.xx) * 0.5f;
                        _19199 = float2(_10576.x - _19140.x, _10550 - _10576.y);
                        break;
                    } while(false);
                    float2 _10373 = abs(_19199);
                    if (any(bool2(_10373.x > 100000.0f.xx.x, _10373.y > 100000.0f.xx.y)))
                    {
                        _19200 = false;
                        break;
                    }
                    float _10381 = length(_19199 * _5675);
                    uint _10596_dummy_parameter;
                    bool _10395 = _10381 > ((8.0f * _5675.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10402;
                    if (_10395)
                    {
                        _10402 = length((r_motion_tp1.Load(int3(int2(floor(_19140 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10596_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5675) < (0.20000000298023223876953125f * _10381);
                    }
                    else
                    {
                        _10402 = _10395;
                    }
                    _19200 = _10402;
                    break;
                } while(false);
                bool _19207;
                do
                {
                    bool _10682 = all(bool2(_19141.x > 0.0f.xx.x, _19141.y > 0.0f.xx.y));
                    bool _10688;
                    if (_10682)
                    {
                        _10688 = all(bool2(_19141.x < 1.0f.xx.x, _19141.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10688 = _10682;
                    }
                    if (!_10688)
                    {
                        _19207 = false;
                        break;
                    }
                    uint _10695_dummy_parameter;
                    float4x4 _19205;
                    do
                    {
                        float4x4 _10709;
                        bool _19204;
                        do
                        {
                            _10709 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19204 = false;
                                break;
                            }
                            uint _10743 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10743 + 32u) * 4 + 0) != 1u)
                            {
                                _19204 = false;
                                break;
                            }
                            uint _19201;
                            _19201 = 0u;
                            for (; _19201 < 4u; _19201++)
                            {
                                for (uint _19202 = 0u; _19202 < 4u; )
                                {
                                    _10709[_19201][_19202] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10743 + (_19201 * 4u)) + _19202) * 4 + 0));
                                    _19202++;
                                    continue;
                                }
                            }
                            _19204 = true;
                            break;
                        } while(false);
                        if (_19204)
                        {
                            _19205 = _10709;
                            break;
                        }
                        _19205 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19206;
                    do
                    {
                        float _10823 = 1.0f - _19141.y;
                        float4 _10834 = mul(float4((float2(_19141.x, _10823) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19141 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10695_dummy_parameter))))), 0)).x, 1.0f), _19205);
                        float _10836 = _10834.w;
                        if (!(_10836 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19206 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10849 = ((_10834.xy / _10836.xx) + 1.0f.xx) * 0.5f;
                        _19206 = float2(_10849.x - _19141.x, _10823 - _10849.y);
                        break;
                    } while(false);
                    float2 _10646 = abs(_19206);
                    if (any(bool2(_10646.x > 100000.0f.xx.x, _10646.y > 100000.0f.xx.y)))
                    {
                        _19207 = false;
                        break;
                    }
                    float _10654 = length(_19206 * _5675);
                    uint _10869_dummy_parameter;
                    bool _10668 = _10654 > ((8.0f * _5675.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10675;
                    if (_10668)
                    {
                        _10675 = length((r_motion_tp1.Load(int3(int2(floor(_19141 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10869_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5675) < (0.20000000298023223876953125f * _10654);
                    }
                    else
                    {
                        _10675 = _10668;
                    }
                    _19207 = _10675;
                    break;
                } while(false);
                float4 _5743 = _8691 * float4(_19186 ? 0.0f : 1.0f, _19193 ? 0.0f : 1.0f, _19200 ? 0.0f : 1.0f, _19207 ? 0.0f : 1.0f);
                float _5745 = dot(_5743, 1.0f.xxxx);
                float4 _19350;
                if (_5745 > 0.001000000047497451305389404296875f)
                {
                    _19350 = _5743 / _5745.xxxx;
                }
                else
                {
                    _19350 = _8691;
                }
                _19349 = _19350;
            }
            else
            {
                _19349 = _8691;
            }
            _20656 = _5716;
            _19348 = _19349;
        }
        else
        {
            _20656 = 0.0f;
            _19348 = _8691;
        }
        bool _5762 = _5454 && (!_19277);
        bool _5771;
        if (_5762)
        {
            _5771 = (_19348.z + _19348.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5771 = _5762;
        }
        bool _5782;
        if (_5771)
        {
            _5782 = length((_19140 - _19137) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5782 = _5771;
        }
        bool _19437;
        if (_5782)
        {
            uint4 _10898 = r_warped_motion_qdata_tp1.Load(int3(_19358, 0));
            uint _10899 = _10898.x;
            bool _19440;
            if (_10899 != 0u)
            {
                float _19426;
                if (_10899 == 0u)
                {
                    _19426 = -1.0f;
                }
                else
                {
                    _19426 = float((_10899 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5792 = _19426 - 0.12000000476837158203125f;
                bool _10918 = all(bool2(_19140.x > 0.0f.xx.x, _19140.y > 0.0f.xx.y));
                bool _10924;
                if (_10918)
                {
                    _10924 = all(bool2(_19140.x < 1.0f.xx.x, _19140.y < 1.0f.xx.y));
                }
                else
                {
                    _10924 = _10918;
                }
                bool _5802;
                if (_10924)
                {
                    uint _10931_dummy_parameter;
                    _5802 = (log(((r_depth_tm1.Load(int3(int2(floor(_19140 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10931_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5792;
                }
                else
                {
                    _5802 = _10924;
                }
                bool _5816;
                if (!_5802)
                {
                    bool _10961 = all(bool2(_19141.x > 0.0f.xx.x, _19141.y > 0.0f.xx.y));
                    bool _10967;
                    if (_10961)
                    {
                        _10967 = all(bool2(_19141.x < 1.0f.xx.x, _19141.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10967 = _10961;
                    }
                    bool _5814;
                    if (_10967)
                    {
                        uint _10974_dummy_parameter;
                        _5814 = (log(((r_depth_tp1.Load(int3(int2(floor(_19141 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10974_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5792;
                    }
                    else
                    {
                        _5814 = _10967;
                    }
                    _5816 = _5814;
                }
                else
                {
                    _5816 = _5802;
                }
                _19440 = _5816;
            }
            else
            {
                _19440 = false;
            }
            _19437 = _19440;
        }
        else
        {
            _19437 = false;
        }
        bool _5821 = _19277 || _19437;
        bool _5826;
        if (_5821)
        {
            bool _11004 = all(bool2(_19137.x > 0.0f.xx.x, _19137.y > 0.0f.xx.y));
            bool _11010;
            if (_11004)
            {
                _11010 = all(bool2(_19137.x < 1.0f.xx.x, _19137.y < 1.0f.xx.y));
            }
            else
            {
                _11010 = _11004;
            }
            _5826 = _11010;
        }
        else
        {
            _5826 = _5821;
        }
        bool _5831;
        if (_5826)
        {
            bool _11015 = all(bool2(_19139.x > 0.0f.xx.x, _19139.y > 0.0f.xx.y));
            bool _11021;
            if (_11015)
            {
                _11021 = all(bool2(_19139.x < 1.0f.xx.x, _19139.y < 1.0f.xx.y));
            }
            else
            {
                _11021 = _11015;
            }
            _5831 = _11021;
        }
        else
        {
            _5831 = _5826;
        }
        float4 _19560;
        if (_5831)
        {
            float _5837 = _19348.x + _19348.y;
            float _5842 = _19348.z + _19348.w;
            float _19455;
            if (_5837 > 0.001000000047497451305389404296875f)
            {
                _19455 = _19348.x / _5837;
            }
            else
            {
                _19455 = _5642;
            }
            _19560 = float4(_19348.x + (_5842 * _19455), _19348.y + (_5842 * (1.0f - _19455)), 0.0f, 0.0f);
        }
        else
        {
            _19560 = _19348;
        }
        bool _11049 = (cbFI_pad0 & 1024u) != 0u;
        bool _11025 = !_11049;
        bool _11026 = !_11025;
        bool _11043;
        if (_11026)
        {
            _11043 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19358.y * cbFI_MvDepthLaneSize.x) + _19358.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11043 = _11025;
        }
        bool _11075;
        if (_11026)
        {
            _11075 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5433.y * cbFI_FlowLaneSize.x) + _5433.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11075 = _11025;
        }
        float _5877 = float(_11075);
        bool _19581;
        float4 _19620;
        float3 _21350;
        if (_11049)
        {
            bool _5887;
            if (_11043)
            {
                _5887 = all(bool2(_19137.x > 0.0f.xx.x, _19137.y > 0.0f.xx.y));
            }
            else
            {
                _5887 = _11043;
            }
            bool _5893;
            if (_5887)
            {
                _5893 = all(bool2(_19137.x < 1.0f.xx.x, _19137.y < 1.0f.xx.y));
            }
            else
            {
                _5893 = _5887;
            }
            bool _5900;
            if (_11043)
            {
                _5900 = all(bool2(_19139.x > 0.0f.xx.x, _19139.y > 0.0f.xx.y));
            }
            else
            {
                _5900 = _11043;
            }
            bool _5906;
            if (_5900)
            {
                _5906 = all(bool2(_19139.x < 1.0f.xx.x, _19139.y < 1.0f.xx.y));
            }
            else
            {
                _5906 = _5900;
            }
            bool _5913;
            if (_11075)
            {
                _5913 = all(bool2(_19140.x > 0.0f.xx.x, _19140.y > 0.0f.xx.y));
            }
            else
            {
                _5913 = _11075;
            }
            bool _5919;
            if (_5913)
            {
                _5919 = all(bool2(_19140.x < 1.0f.xx.x, _19140.y < 1.0f.xx.y));
            }
            else
            {
                _5919 = _5913;
            }
            bool _5926;
            if (_11075)
            {
                _5926 = all(bool2(_19141.x > 0.0f.xx.x, _19141.y > 0.0f.xx.y));
            }
            else
            {
                _5926 = _11075;
            }
            bool _5932;
            if (_5926)
            {
                _5932 = all(bool2(_19141.x < 1.0f.xx.x, _19141.y < 1.0f.xx.y));
            }
            else
            {
                _5932 = _5926;
            }
            bool _5934 = !_11043;
            if (_5934)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11117;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11117);
                }
            }
            bool _5939 = !_11075;
            if (_5939)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11127;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11127);
                }
            }
            if (_11043 && _5939)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11137;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11137);
                }
            }
            if (_5934 && _11075)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11147;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11147);
                }
            }
            float _5958 = float(_5893);
            float _5960 = float(_5906);
            bool _5963 = _5919 && _5932;
            float _19489;
            if (_5963)
            {
                _19489 = 1.0f;
            }
            else
            {
                _19489 = (_5919 || _5932) ? 0.5f : 0.0f;
            }
            bool _19504;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5893)) && (!_5906))
            {
                bool _5993;
                if (_5963)
                {
                    float _19497;
                    do
                    {
                        bool _11231 = all(bool2(_19140.x > 0.0f.xx.x, _19140.y > 0.0f.xx.y));
                        bool _11237;
                        if (_11231)
                        {
                            _11237 = all(bool2(_19140.x < 1.0f.xx.x, _19140.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11237 = _11231;
                        }
                        bool _11168 = !_11237;
                        bool _11175;
                        if (!_11168)
                        {
                            bool _11242 = all(bool2(_19141.x > 0.0f.xx.x, _19141.y > 0.0f.xx.y));
                            bool _11248;
                            if (_11242)
                            {
                                _11248 = all(bool2(_19141.x < 1.0f.xx.x, _19141.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11248 = _11242;
                            }
                            _11175 = !_11248;
                        }
                        else
                        {
                            _11175 = _11168;
                        }
                        if (_11175)
                        {
                            _19497 = 0.0f;
                            break;
                        }
                        uint _11255_dummy_parameter;
                        uint _11271_dummy_parameter;
                        float4x4 _19496;
                        do
                        {
                            float4x4 _11285;
                            bool _19495;
                            do
                            {
                                _11285 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _19495 = false;
                                    break;
                                }
                                uint _11319 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11319 + 32u) * 4 + 0) != 1u)
                                {
                                    _19495 = false;
                                    break;
                                }
                                uint _19492;
                                _19492 = 0u;
                                for (; _19492 < 4u; _19492++)
                                {
                                    for (uint _19493 = 0u; _19493 < 4u; )
                                    {
                                        _11285[_19492][_19493] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11319 + 16u) + (_19492 * 4u)) + _19493) * 4 + 0));
                                        _19493++;
                                        continue;
                                    }
                                }
                                _19495 = true;
                                break;
                            } while(false);
                            if (_19495)
                            {
                                _19496 = _11285;
                                break;
                            }
                            _19496 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11196 = mul(float4((float2(_19140.x, 1.0f - _19140.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19140 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11255_dummy_parameter))))), 0)).x, 1.0f), _19496);
                        float _11198 = _11196.w;
                        if (abs(_11198) < 9.9999999747524270787835121154785e-07f)
                        {
                            _19497 = 0.0f;
                            break;
                        }
                        float _11209 = abs(cbFI_DeviceToViewDepth.y / ((_11196.z / _11198) - cbFI_DeviceToViewDepth.x));
                        float _11212 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19141 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11271_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _19497 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11209 - _11212) / max(max(_11209, _11212), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5993 = _19497 >= 0.5f;
                }
                else
                {
                    _5993 = _5963;
                }
                bool _6001;
                if (_5993)
                {
                    _6001 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _6001 = _5993;
                }
                bool _19505;
                if (_6001)
                {
                    uint _11423_dummy_parameter;
                    float4x4 _19502;
                    do
                    {
                        float4x4 _11437;
                        bool _19501;
                        do
                        {
                            _11437 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19501 = false;
                                break;
                            }
                            uint _11471 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11471 + 32u) * 4 + 0) != 1u)
                            {
                                _19501 = false;
                                break;
                            }
                            uint _19498;
                            _19498 = 0u;
                            for (; _19498 < 4u; _19498++)
                            {
                                for (uint _19499 = 0u; _19499 < 4u; )
                                {
                                    _11437[_19498][_19499] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11471 + 16u) + (_19498 * 4u)) + _19499) * 4 + 0));
                                    _19499++;
                                    continue;
                                }
                            }
                            _19501 = true;
                            break;
                        } while(false);
                        if (_19501)
                        {
                            _19502 = _11437;
                            break;
                        }
                        _19502 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _19503;
                    do
                    {
                        float _11551 = 1.0f - _19140.y;
                        float4 _11562 = mul(float4((float2(_19140.x, _11551) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19140 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11423_dummy_parameter))))), 0)).x, 1.0f), _19502);
                        float _11564 = _11562.w;
                        if (!(_11564 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19503 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11577 = ((_11562.xy / _11564.xx) + 1.0f.xx) * 0.5f;
                        _19503 = float2(_11577.x - _19140.x, _11551 - _11577.y);
                        break;
                    } while(false);
                    float2 _6014 = float2(cbFI_DisplaySize);
                    _19505 = length(((_19140 + _19503) - _19141) * _6014) <= ((0.100000001490116119384765625f * length(_19503 * _6014)) + 8.0f);
                }
                else
                {
                    _19505 = _5993;
                }
                _19504 = _19505;
            }
            else
            {
                _19504 = true;
            }
            bool _6028 = !_19504;
            bool _22856 = _6028 ? false : _5932;
            bool _22857 = _6028 ? false : _5919;
            bool _19582;
            float4 _19621;
            if (!(((_5893 && _5906) && _22857) && _22856))
            {
                float4 _6050 = _19560 * float4(_5958, _5960, float(_22857), float(_22856));
                float _6052 = dot(_6050, 1.0f.xxxx);
                bool _6055 = !(_6052 > 0.0f);
                float4 _19622;
                if (!_6055)
                {
                    _19622 = _6050 / _6052.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11599;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11599);
                    }
                    _19622 = 0.0f.xxxx;
                }
                _19621 = _19622;
                _19582 = _6055;
            }
            else
            {
                _19621 = _19560;
                _19582 = false;
            }
            _21350 = float3(_5958, _5960, _19489);
            _19620 = _19621;
            _19581 = _19582;
        }
        else
        {
            _21350 = float3(float(_11043), _5877, 0.0f);
            _19620 = _19560;
            _19581 = false;
        }
        bool _6073 = !_19581;
        float4 _19713;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6073)
        {
            float _6080 = _19620.x + _19620.y;
            float4 _19714;
            if (_6080 > 0.001000000047497451305389404296875f)
            {
                _19714 = float4(_19620.x / _6080, _19620.y / _6080, 0.0f, 0.0f);
            }
            else
            {
                _19714 = float4(_5642, cbFI_Timestep, 0.0f, 0.0f);
            }
            _19713 = _19714;
        }
        else
        {
            _19713 = _19620;
        }
        float4 _19890;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6073) && _11043)
        {
            float _19687;
            do
            {
                uint4 _11739 = r_warped_motion_qdata_tp1.Load(int3(_19358, 0));
                uint _11740 = _11739.x;
                if (_11740 != 0u)
                {
                    float _19686;
                    if (_11740 == 0u)
                    {
                        _19686 = -1.0f;
                    }
                    else
                    {
                        _19686 = float((_11740 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19687 = _19686;
                    break;
                }
                int _19669;
                uint _19670;
                _19670 = _11740;
                _19669 = -1;
                uint _19685;
                for (; _19669 <= 1; _19670 = _19685, _19669++)
                {
                    _19685 = _19670;
                    for (int _19683 = -1; _19683 <= 1; )
                    {
                        _19685 = max(_19685, r_warped_motion_qdata_tp1.Load(int3(clamp(_19358 + int2(_19683, _19669), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _19683++;
                        continue;
                    }
                }
                if (_19670 != 0u)
                {
                    float _19682;
                    if (_19670 == 0u)
                    {
                        _19682 = -1.0f;
                    }
                    else
                    {
                        _19682 = float((_19670 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19687 = _19682;
                    break;
                }
                uint _19672;
                _19672 = 4294967295u;
                uint _22557;
                for (int _19671 = 0; _19671 < 8; _19672 = _22557, _19671++)
                {
                    int _19675 = 0;
                    for (;;)
                    {
                        if (_19675 < 5)
                        {
                            int2 _11690 = _19358 + (_1251[_19671] * _1260[_19675].xx);
                            bool _11693 = any(bool2(_11690.x < int2(0, 0).x, _11690.y < int2(0, 0).y));
                            bool _11701;
                            if (!_11693)
                            {
                                _11701 = any(bool2(_11690.x >= cbFI_MvDepthLaneSize.x, _11690.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11701 = _11693;
                            }
                            if (_11701)
                            {
                                _22557 = _19672;
                                break;
                            }
                            uint4 _11779 = r_warped_motion_qdata_tp1.Load(int3(_11690, 0));
                            uint _11780 = _11779.x;
                            if (_11780 != 0u)
                            {
                                _22557 = min(_19672, _11780);
                                break;
                            }
                            _19675++;
                            continue;
                        }
                        else
                        {
                            _22557 = _19672;
                            break;
                        }
                    }
                }
                float _19674;
                if (_19672 == 4294967295u)
                {
                    _19674 = -1.0f;
                }
                else
                {
                    float _19673;
                    if (_19672 == 0u)
                    {
                        _19673 = -1.0f;
                    }
                    else
                    {
                        _19673 = float((_19672 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19674 = _19673;
                }
                _19687 = _19674;
                break;
            } while(false);
            float _6116 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6119 = r_warped_motion_qdata_tp1.Load(int3(_19358, 0)).x == 0u;
            bool _6125;
            if (_6119)
            {
                bool _11805 = all(bool2(_19137.x > 0.0f.xx.x, _19137.y > 0.0f.xx.y));
                bool _11811;
                if (_11805)
                {
                    _11811 = all(bool2(_19137.x < 1.0f.xx.x, _19137.y < 1.0f.xx.y));
                }
                else
                {
                    _11811 = _11805;
                }
                _6125 = _11811;
            }
            else
            {
                _6125 = _6119;
            }
            bool _6130;
            if (_6125)
            {
                bool _11816 = all(bool2(_19139.x > 0.0f.xx.x, _19139.y > 0.0f.xx.y));
                bool _11822;
                if (_11816)
                {
                    _11822 = all(bool2(_19139.x < 1.0f.xx.x, _19139.y < 1.0f.xx.y));
                }
                else
                {
                    _11822 = _11816;
                }
                _6130 = _11822;
            }
            else
            {
                _6130 = _6125;
            }
            bool _19699;
            float4 _19708;
            if (_6130)
            {
                uint _11829_dummy_parameter;
                float _11853 = log(((r_depth_tm1.Load(int3(int2(floor(_19137 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11829_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _11861_dummy_parameter;
                float _11885 = log(((r_depth_tp1.Load(int3(int2(floor(_19139 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11861_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _6141 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6148;
                if (_6141)
                {
                    _6148 = _11885 > (_11853 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6148 = _6141;
                }
                bool _19704;
                float4 _19726;
                if (_6148)
                {
                    _19726 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _19704 = true;
                }
                else
                {
                    bool _6154 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6161;
                    if (_6154)
                    {
                        _6161 = _11853 > (_11885 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6161 = _6154;
                    }
                    bool4 _22858 = _6161.xxxx;
                    _19726 = float4(_22858.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _19713.x, _22858.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _19713.y, _22858.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _19713.z, _22858.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _19713.w);
                    _19704 = _6161 ? true : false;
                }
                _19708 = _19726;
                _19699 = _19704;
            }
            else
            {
                _19708 = _19713;
                _19699 = false;
            }
            float4 _19781;
            if (_19699)
            {
                _19781 = 1.0f.xxxx;
            }
            else
            {
                bool _6172 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6178;
                if (_6172)
                {
                    _6178 = _19708.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6178 = _6172;
                }
                bool _6183;
                if (_6178)
                {
                    bool _11891 = all(bool2(_19139.x > 0.0f.xx.x, _19139.y > 0.0f.xx.y));
                    bool _11897;
                    if (_11891)
                    {
                        _11897 = all(bool2(_19139.x < 1.0f.xx.x, _19139.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11897 = _11891;
                    }
                    _6183 = _11897;
                }
                else
                {
                    _6183 = _6178;
                }
                float4 _19782;
                if (_6183)
                {
                    float _19735;
                    if (_19687 >= 0.0f)
                    {
                        _19735 = _19687 - _6116;
                    }
                    else
                    {
                        float _19731;
                        _19731 = 2.0f;
                        float _11954;
                        for (int _19730 = 0; _19730 < 24; _19731 = _11954, _19730++)
                        {
                            float _11918 = float(_19730 & 7) * 0.785398185253143310546875f;
                            int _11920 = _19730 >> 3;
                            int _19732;
                            if (_11920 == 0)
                            {
                                _19732 = 16;
                            }
                            else
                            {
                                _19732 = (_11920 == 1) ? 48 : 96;
                            }
                            uint _11986_dummy_parameter;
                            _11954 = min(_19731, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19139 + ((cbFI_MvDepthLaneSizeRcp * float(_19732)) * float2(cos(_11918), sin(_11918))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11986_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _19735 = _19731;
                    }
                    uint _12018_dummy_parameter;
                    float4 _19783;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_19139 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12018_dummy_parameter))))), 0)).x) > ((exp((_19735 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _19783 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _19783 = 1.0f.xxxx;
                    }
                    _19782 = _19783;
                }
                else
                {
                    _19782 = 1.0f.xxxx;
                }
                _19781 = _19782;
            }
            bool _6211 = _19687 >= 0.0f;
            bool _6212 = (!_19699) && _6211;
            bool _6219;
            if (_6212)
            {
                _6219 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6219 = _6212;
            }
            bool _6225;
            if (_6219)
            {
                _6225 = _19708.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6225 = _6219;
            }
            bool _6230;
            if (_6225)
            {
                bool _12043 = all(bool2(_19137.x > 0.0f.xx.x, _19137.y > 0.0f.xx.y));
                bool _12049;
                if (_12043)
                {
                    _12049 = all(bool2(_19137.x < 1.0f.xx.x, _19137.y < 1.0f.xx.y));
                }
                else
                {
                    _12049 = _12043;
                }
                _6230 = _12049;
            }
            else
            {
                _6230 = _6225;
            }
            float4 _19806;
            if (_6230)
            {
                float _19775;
                if (_6211)
                {
                    _19775 = _19687 - _6116;
                }
                else
                {
                    float _19771;
                    _19771 = 2.0f;
                    float _12106;
                    for (int _19770 = 0; _19770 < 24; _19771 = _12106, _19770++)
                    {
                        float _12070 = float(_19770 & 7) * 0.785398185253143310546875f;
                        int _12072 = _19770 >> 3;
                        int _19772;
                        if (_12072 == 0)
                        {
                            _19772 = 16;
                        }
                        else
                        {
                            _19772 = (_12072 == 1) ? 48 : 96;
                        }
                        uint _12122_dummy_parameter;
                        _12106 = min(_19771, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19137 + ((cbFI_MvDepthLaneSizeRcp * float(_19772)) * float2(cos(_12070), sin(_12070))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12122_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _19775 = _19771;
                }
                uint _12170_dummy_parameter;
                float4 _19807;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_19137 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12170_dummy_parameter))))), 0)).x) > ((exp((_19775 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _18833 = _19781;
                    _18833.x = 0.0f;
                    _19807 = _18833;
                }
                else
                {
                    _19807 = _19781;
                }
                _19806 = _19807;
            }
            else
            {
                _19806 = _19781;
            }
            float4 _19819;
            if (_6212)
            {
                float _12197 = (exp(((_19687 - _6116) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6268 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6274;
                if (_6268)
                {
                    _6274 = _19708.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6274 = _6268;
                }
                bool _6279;
                if (_6274)
                {
                    bool _12202 = all(bool2(_19141.x > 0.0f.xx.x, _19141.y > 0.0f.xx.y));
                    bool _12208;
                    if (_12202)
                    {
                        _12208 = all(bool2(_19141.x < 1.0f.xx.x, _19141.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12208 = _12202;
                    }
                    _6279 = _12208;
                }
                else
                {
                    _6279 = _6274;
                }
                bool _6287;
                if (_6279)
                {
                    uint _12215_dummy_parameter;
                    _6287 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19141 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12215_dummy_parameter))))), 0)).x) > _12197;
                }
                else
                {
                    _6287 = _6279;
                }
                float4 _19817;
                if (_6287)
                {
                    float4 _18836 = _19806;
                    _18836.w = 0.0f;
                    _19817 = _18836;
                }
                else
                {
                    _19817 = _19806;
                }
                bool _6294 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6300;
                if (_6294)
                {
                    _6300 = _19708.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6300 = _6294;
                }
                bool _6305;
                if (_6300)
                {
                    bool _12233 = all(bool2(_19140.x > 0.0f.xx.x, _19140.y > 0.0f.xx.y));
                    bool _12239;
                    if (_12233)
                    {
                        _12239 = all(bool2(_19140.x < 1.0f.xx.x, _19140.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12239 = _12233;
                    }
                    _6305 = _12239;
                }
                else
                {
                    _6305 = _6300;
                }
                bool _6313;
                if (_6305)
                {
                    uint _12246_dummy_parameter;
                    _6313 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19140 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12246_dummy_parameter))))), 0)).x) > _12197;
                }
                else
                {
                    _6313 = _6305;
                }
                float4 _19820;
                if (_6313)
                {
                    float4 _18839 = _19817;
                    _18839.z = 0.0f;
                    _19820 = _18839;
                }
                else
                {
                    _19820 = _19817;
                }
                _19819 = _19820;
            }
            else
            {
                _19819 = _19806;
            }
            float4 _19891;
            if (any(bool4(_19819.x < 1.0f.xxxx.x, _19819.y < 1.0f.xxxx.y, _19819.z < 1.0f.xxxx.z, _19819.w < 1.0f.xxxx.w)))
            {
                float4 _6324 = _19708 * _19819;
                float _6326 = dot(_6324, 1.0f.xxxx);
                float4 _19892;
                if (_6326 > 0.0f)
                {
                    _19892 = _6324 / _6326.xxxx;
                }
                else
                {
                    bool _6337 = _19819.y == 0.0f;
                    bool _6343;
                    if (_6337)
                    {
                        _6343 = _19819.x > 0.0f;
                    }
                    else
                    {
                        _6343 = _6337;
                    }
                    bool _6348;
                    if (_6343)
                    {
                        bool _12264 = all(bool2(_19137.x > 0.0f.xx.x, _19137.y > 0.0f.xx.y));
                        bool _12270;
                        if (_12264)
                        {
                            _12270 = all(bool2(_19137.x < 1.0f.xx.x, _19137.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12270 = _12264;
                        }
                        _6348 = _12270;
                    }
                    else
                    {
                        _6348 = _6343;
                    }
                    float4 _19893;
                    if (_6348)
                    {
                        _19893 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6353 = _19819.x == 0.0f;
                        bool _6359;
                        if (_6353)
                        {
                            _6359 = _19819.y > 0.0f;
                        }
                        else
                        {
                            _6359 = _6353;
                        }
                        bool _6364;
                        if (_6359)
                        {
                            bool _12275 = all(bool2(_19139.x > 0.0f.xx.x, _19139.y > 0.0f.xx.y));
                            bool _12281;
                            if (_12275)
                            {
                                _12281 = all(bool2(_19139.x < 1.0f.xx.x, _19139.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12281 = _12275;
                            }
                            _6364 = _12281;
                        }
                        else
                        {
                            _6364 = _6359;
                        }
                        bool4 _22861 = _6364.xxxx;
                        _19893 = float4(_22861.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _19708.x, _22861.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _19708.y, _22861.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _19708.z, _22861.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _19708.w);
                    }
                    _19892 = _19893;
                }
                _19891 = _19892;
            }
            else
            {
                _19891 = _19708;
            }
            _19890 = _19891;
        }
        else
        {
            _19890 = _19713;
        }
        float4 _20620;
        bool _20926;
        float3 _21098;
        if (((cbFI_pad0 & 32768u) != 0u) && _6073)
        {
            bool _6381 = _19890.x > 0.00999999977648258209228515625f;
            bool _6384 = _19890.y > 0.00999999977648258209228515625f;
            bool _6393 = (_19890.z + _19890.w) > 0.0199999995529651641845703125f;
            bool _6399;
            if (_6393)
            {
                bool _12286 = all(bool2(_19140.x > 0.0f.xx.x, _19140.y > 0.0f.xx.y));
                bool _12292;
                if (_12286)
                {
                    _12292 = all(bool2(_19140.x < 1.0f.xx.x, _19140.y < 1.0f.xx.y));
                }
                else
                {
                    _12292 = _12286;
                }
                _6399 = _12292;
            }
            else
            {
                _6399 = _6393;
            }
            bool _6404;
            if (_6399)
            {
                bool _12297 = all(bool2(_19141.x > 0.0f.xx.x, _19141.y > 0.0f.xx.y));
                bool _12303;
                if (_12297)
                {
                    _12303 = all(bool2(_19141.x < 1.0f.xx.x, _19141.y < 1.0f.xx.y));
                }
                else
                {
                    _12303 = _12297;
                }
                _6404 = _12303;
            }
            else
            {
                _6404 = _6399;
            }
            bool _6411;
            if (_6404)
            {
                float _19906;
                do
                {
                    bool _12386 = all(bool2(_19140.x > 0.0f.xx.x, _19140.y > 0.0f.xx.y));
                    bool _12392;
                    if (_12386)
                    {
                        _12392 = all(bool2(_19140.x < 1.0f.xx.x, _19140.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12392 = _12386;
                    }
                    bool _12323 = !_12392;
                    bool _12330;
                    if (!_12323)
                    {
                        bool _12397 = all(bool2(_19141.x > 0.0f.xx.x, _19141.y > 0.0f.xx.y));
                        bool _12403;
                        if (_12397)
                        {
                            _12403 = all(bool2(_19141.x < 1.0f.xx.x, _19141.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12403 = _12397;
                        }
                        _12330 = !_12403;
                    }
                    else
                    {
                        _12330 = _12323;
                    }
                    if (_12330)
                    {
                        _19906 = 0.0f;
                        break;
                    }
                    uint _12410_dummy_parameter;
                    uint _12426_dummy_parameter;
                    float4x4 _19905;
                    do
                    {
                        float4x4 _12440;
                        bool _19904;
                        do
                        {
                            _12440 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19904 = false;
                                break;
                            }
                            uint _12474 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12474 + 32u) * 4 + 0) != 1u)
                            {
                                _19904 = false;
                                break;
                            }
                            uint _19901;
                            _19901 = 0u;
                            for (; _19901 < 4u; _19901++)
                            {
                                for (uint _19902 = 0u; _19902 < 4u; )
                                {
                                    _12440[_19901][_19902] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12474 + 16u) + (_19901 * 4u)) + _19902) * 4 + 0));
                                    _19902++;
                                    continue;
                                }
                            }
                            _19904 = true;
                            break;
                        } while(false);
                        if (_19904)
                        {
                            _19905 = _12440;
                            break;
                        }
                        _19905 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12351 = mul(float4((float2(_19140.x, 1.0f - _19140.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19140 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12410_dummy_parameter))))), 0)).x, 1.0f), _19905);
                    float _12353 = _12351.w;
                    if (abs(_12353) < 9.9999999747524270787835121154785e-07f)
                    {
                        _19906 = 0.0f;
                        break;
                    }
                    float _12364 = abs(cbFI_DeviceToViewDepth.y / ((_12351.z / _12353) - cbFI_DeviceToViewDepth.x));
                    float _12367 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19141 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12426_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _19906 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12364 - _12367) / max(max(_12364, _12367), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6411 = _19906 < 0.5f;
            }
            else
            {
                _6411 = _6404;
            }
            float4 _19925;
            if (_6411)
            {
                uint _12578_dummy_parameter;
                uint _12609_dummy_parameter;
                float4 _19926;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19140 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12578_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19141 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12609_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _19926 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _19926 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _19925 = _19926;
            }
            else
            {
                _19925 = 1.0f.xxxx;
            }
            bool _6435;
            if (_11043)
            {
                bool _12638 = all(bool2(_19137.x > 0.0f.xx.x, _19137.y > 0.0f.xx.y));
                bool _12644;
                if (_12638)
                {
                    _12644 = all(bool2(_19137.x < 1.0f.xx.x, _19137.y < 1.0f.xx.y));
                }
                else
                {
                    _12644 = _12638;
                }
                _6435 = _12644;
            }
            else
            {
                _6435 = _11043;
            }
            bool _6441;
            if (_11043)
            {
                bool _12649 = all(bool2(_19139.x > 0.0f.xx.x, _19139.y > 0.0f.xx.y));
                bool _12655;
                if (_12649)
                {
                    _12655 = all(bool2(_19139.x < 1.0f.xx.x, _19139.y < 1.0f.xx.y));
                }
                else
                {
                    _12655 = _12649;
                }
                _6441 = _12655;
            }
            else
            {
                _6441 = _11043;
            }
            bool _6447;
            if (_11075)
            {
                bool _12660 = all(bool2(_19140.x > 0.0f.xx.x, _19140.y > 0.0f.xx.y));
                bool _12666;
                if (_12660)
                {
                    _12666 = all(bool2(_19140.x < 1.0f.xx.x, _19140.y < 1.0f.xx.y));
                }
                else
                {
                    _12666 = _12660;
                }
                _6447 = _12666;
            }
            else
            {
                _6447 = _11075;
            }
            bool _6453;
            if (_11075)
            {
                bool _12671 = all(bool2(_19141.x > 0.0f.xx.x, _19141.y > 0.0f.xx.y));
                bool _12677;
                if (_12671)
                {
                    _12677 = all(bool2(_19141.x < 1.0f.xx.x, _19141.y < 1.0f.xx.y));
                }
                else
                {
                    _12677 = _12671;
                }
                _6453 = _12677;
            }
            else
            {
                _6453 = _11075;
            }
            bool _6456 = _6447 != _6453;
            bool _6462;
            if (_6456)
            {
                _6462 = _6435 || _6441;
            }
            else
            {
                _6462 = _6456;
            }
            float4 _20028;
            if (_6462)
            {
                float4 _18866 = _19925;
                _18866.z = 0.0f;
                _18866.w = 0.0f;
                _20028 = _18866;
            }
            else
            {
                _20028 = _19925;
            }
            bool _6469 = _6435 && _6381;
            bool _6472 = _6441 && _6384;
            float4 _20133;
            float3 _21207;
            if (_6469 || _6472)
            {
                float _20023;
                do
                {
                    uint4 _12816 = r_warped_motion_qdata_tp1.Load(int3(_19358, 0));
                    uint _12817 = _12816.x;
                    if (_12817 != 0u)
                    {
                        float _20022;
                        if (_12817 == 0u)
                        {
                            _20022 = -1.0f;
                        }
                        else
                        {
                            _20022 = float((_12817 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20023 = _20022;
                        break;
                    }
                    int _20005;
                    uint _20006;
                    _20006 = _12817;
                    _20005 = -1;
                    uint _20021;
                    for (; _20005 <= 1; _20006 = _20021, _20005++)
                    {
                        _20021 = _20006;
                        for (int _20019 = -1; _20019 <= 1; )
                        {
                            _20021 = max(_20021, r_warped_motion_qdata_tp1.Load(int3(clamp(_19358 + int2(_20019, _20005), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20019++;
                            continue;
                        }
                    }
                    if (_20006 != 0u)
                    {
                        float _20018;
                        if (_20006 == 0u)
                        {
                            _20018 = -1.0f;
                        }
                        else
                        {
                            _20018 = float((_20006 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20023 = _20018;
                        break;
                    }
                    uint _20008;
                    _20008 = 4294967295u;
                    uint _22558;
                    for (int _20007 = 0; _20007 < 8; _20008 = _22558, _20007++)
                    {
                        int _20011 = 0;
                        for (;;)
                        {
                            if (_20011 < 5)
                            {
                                int2 _12767 = _19358 + (_1251[_20007] * _1260[_20011].xx);
                                bool _12770 = any(bool2(_12767.x < int2(0, 0).x, _12767.y < int2(0, 0).y));
                                bool _12778;
                                if (!_12770)
                                {
                                    _12778 = any(bool2(_12767.x >= cbFI_MvDepthLaneSize.x, _12767.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12778 = _12770;
                                }
                                if (_12778)
                                {
                                    _22558 = _20008;
                                    break;
                                }
                                uint4 _12856 = r_warped_motion_qdata_tp1.Load(int3(_12767, 0));
                                uint _12857 = _12856.x;
                                if (_12857 != 0u)
                                {
                                    _22558 = min(_20008, _12857);
                                    break;
                                }
                                _20011++;
                                continue;
                            }
                            else
                            {
                                _22558 = _20008;
                                break;
                            }
                        }
                    }
                    float _20010;
                    if (_20008 == 4294967295u)
                    {
                        _20010 = -1.0f;
                    }
                    else
                    {
                        float _20009;
                        if (_20008 == 0u)
                        {
                            _20009 = -1.0f;
                        }
                        else
                        {
                            _20009 = float((_20008 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20010 = _20009;
                    }
                    _20023 = _20010;
                    break;
                } while(false);
                bool _6480 = _20023 < 0.0f;
                float _20024;
                if (_6480)
                {
                    _20024 = 0.0f;
                }
                else
                {
                    _20024 = _20023 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12878_dummy_parameter;
                uint _12910_dummy_parameter;
                float4 _20061;
                if ((_6480 && _6469) && _6472)
                {
                    uint _12942_dummy_parameter;
                    float _12966 = log(((r_depth_tm1.Load(int3(int2(floor(_19137 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12942_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12974_dummy_parameter;
                    float _12998 = log(((r_depth_tp1.Load(int3(int2(floor(_19139 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12974_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20062;
                    if (_12966 > (_12998 + 0.07999999821186065673828125f))
                    {
                        float4 _18870 = _20028;
                        _18870.x = 0.0f;
                        _20062 = _18870;
                    }
                    else
                    {
                        float4 _20063;
                        if (_12998 > (_12966 + 0.07999999821186065673828125f))
                        {
                            float4 _18872 = _20028;
                            _18872.y = 0.0f;
                            _20063 = _18872;
                        }
                        else
                        {
                            _20063 = _20028;
                        }
                        _20062 = _20063;
                    }
                    _20061 = _20062;
                }
                else
                {
                    _20061 = _20028;
                }
                float _6532 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6534 = _20023 >= 0.0f;
                float _20044;
                if (_6534)
                {
                    _20044 = _20023 - _6532;
                }
                else
                {
                    float _20040;
                    if (_6469)
                    {
                        float _20039;
                        _20039 = 2.0f;
                        float _13056;
                        for (int _20038 = 0; _20038 < 24; _20039 = _13056, _20038++)
                        {
                            float _13020 = float(_20038 & 7) * 0.785398185253143310546875f;
                            int _13022 = _20038 >> 3;
                            int _20041;
                            if (_13022 == 0)
                            {
                                _20041 = 16;
                            }
                            else
                            {
                                _20041 = (_13022 == 1) ? 48 : 96;
                            }
                            uint _13072_dummy_parameter;
                            _13056 = min(_20039, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19137 + ((cbFI_MvDepthLaneSizeRcp * float(_20041)) * float2(cos(_13020), sin(_13020))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13072_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20040 = _20039;
                    }
                    else
                    {
                        _20040 = 0.0f;
                    }
                    _20044 = _20040;
                }
                float _20051;
                if (_6534)
                {
                    _20051 = _20023 - _6532;
                }
                else
                {
                    float _20047;
                    if (_6472)
                    {
                        float _20046;
                        _20046 = 2.0f;
                        float _13170;
                        for (int _20045 = 0; _20045 < 24; _20046 = _13170, _20045++)
                        {
                            float _13134 = float(_20045 & 7) * 0.785398185253143310546875f;
                            int _13136 = _20045 >> 3;
                            int _20048;
                            if (_13136 == 0)
                            {
                                _20048 = 16;
                            }
                            else
                            {
                                _20048 = (_13136 == 1) ? 48 : 96;
                            }
                            uint _13202_dummy_parameter;
                            _13170 = min(_20046, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19139 + ((cbFI_MvDepthLaneSizeRcp * float(_20048)) * float2(cos(_13134), sin(_13134))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13202_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20047 = _20046;
                    }
                    else
                    {
                        _20047 = 0.0f;
                    }
                    _20051 = _20047;
                }
                float _20052;
                if (_6469)
                {
                    uint _13234_dummy_parameter;
                    _20052 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_19137 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13234_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20052 = 0.0f;
                }
                float _20053;
                if (_6472)
                {
                    uint _13254_dummy_parameter;
                    _20053 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_19139 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13254_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20053 = 0.0f;
                }
                bool _6589;
                if (_6469)
                {
                    _6589 = _20052 > ((exp((_20044 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6589 = _6469;
                }
                float4 _20069;
                if (_6589)
                {
                    float4 _18874 = _20061;
                    _18874.x = 0.0f;
                    _20069 = _18874;
                }
                else
                {
                    _20069 = _20061;
                }
                bool _6601;
                if (_6472)
                {
                    _6601 = _20053 > ((exp((_20051 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6601 = _6472;
                }
                float4 _20071;
                if (_6601)
                {
                    float4 _18876 = _20069;
                    _18876.y = 0.0f;
                    _20071 = _18876;
                }
                else
                {
                    _20071 = _20069;
                }
                float4 _20134;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6534)
                {
                    bool _6621;
                    if (_6469)
                    {
                        _6621 = _20052 < ((exp((_20044 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6621 = _6469;
                    }
                    float4 _20073;
                    if (_6621)
                    {
                        float4 _18878 = _20071;
                        _18878.x = 0.0f;
                        _20073 = _18878;
                    }
                    else
                    {
                        _20073 = _20071;
                    }
                    bool _6633;
                    if (_6472)
                    {
                        _6633 = _20053 < ((exp((_20051 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6633 = _6472;
                    }
                    float4 _20135;
                    if (_6633)
                    {
                        float4 _18880 = _20073;
                        _18880.y = 0.0f;
                        _20135 = _18880;
                    }
                    else
                    {
                        _20135 = _20073;
                    }
                    _20134 = _20135;
                }
                else
                {
                    _20134 = _20071;
                }
                _21207 = float3(_20024, log(((r_depth_tm1.Load(int3(int2(floor(_19137 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12878_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_19139 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12910_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _20133 = _20134;
            }
            else
            {
                _21207 = float3(0.0f, 0.0f, 0.5f);
                _20133 = _20028;
            }
            bool _6644 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6393;
            bool _6650;
            if (_6644)
            {
                _6650 = _6447 || _6453;
            }
            else
            {
                _6650 = _6644;
            }
            float4 _20176;
            if (_6650)
            {
                float _20128;
                do
                {
                    uint4 _13434 = r_warped_motion_qdata_tp1.Load(int3(_19358, 0));
                    uint _13435 = _13434.x;
                    if (_13435 != 0u)
                    {
                        float _20127;
                        if (_13435 == 0u)
                        {
                            _20127 = -1.0f;
                        }
                        else
                        {
                            _20127 = float((_13435 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20128 = _20127;
                        break;
                    }
                    int _20110;
                    uint _20111;
                    _20111 = _13435;
                    _20110 = -1;
                    uint _20126;
                    for (; _20110 <= 1; _20111 = _20126, _20110++)
                    {
                        _20126 = _20111;
                        for (int _20124 = -1; _20124 <= 1; )
                        {
                            _20126 = max(_20126, r_warped_motion_qdata_tp1.Load(int3(clamp(_19358 + int2(_20124, _20110), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20124++;
                            continue;
                        }
                    }
                    if (_20111 != 0u)
                    {
                        float _20123;
                        if (_20111 == 0u)
                        {
                            _20123 = -1.0f;
                        }
                        else
                        {
                            _20123 = float((_20111 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20128 = _20123;
                        break;
                    }
                    uint _20113;
                    _20113 = 4294967295u;
                    uint _22559;
                    for (int _20112 = 0; _20112 < 8; _20113 = _22559, _20112++)
                    {
                        int _20116 = 0;
                        for (;;)
                        {
                            if (_20116 < 5)
                            {
                                int2 _13385 = _19358 + (_1251[_20112] * _1260[_20116].xx);
                                bool _13388 = any(bool2(_13385.x < int2(0, 0).x, _13385.y < int2(0, 0).y));
                                bool _13396;
                                if (!_13388)
                                {
                                    _13396 = any(bool2(_13385.x >= cbFI_MvDepthLaneSize.x, _13385.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13396 = _13388;
                                }
                                if (_13396)
                                {
                                    _22559 = _20113;
                                    break;
                                }
                                uint4 _13474 = r_warped_motion_qdata_tp1.Load(int3(_13385, 0));
                                uint _13475 = _13474.x;
                                if (_13475 != 0u)
                                {
                                    _22559 = min(_20113, _13475);
                                    break;
                                }
                                _20116++;
                                continue;
                            }
                            else
                            {
                                _22559 = _20113;
                                break;
                            }
                        }
                    }
                    float _20115;
                    if (_20113 == 4294967295u)
                    {
                        _20115 = -1.0f;
                    }
                    else
                    {
                        float _20114;
                        if (_20113 == 0u)
                        {
                            _20114 = -1.0f;
                        }
                        else
                        {
                            _20114 = float((_20113 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20115 = _20114;
                    }
                    _20128 = _20115;
                    break;
                } while(false);
                float4 _20177;
                if (_20128 >= 0.0f)
                {
                    float _13496 = (exp((_20128 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6669;
                    if (_6447)
                    {
                        uint _13503_dummy_parameter;
                        _6669 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19140 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13503_dummy_parameter))))), 0)).x) > _13496;
                    }
                    else
                    {
                        _6669 = _6447;
                    }
                    float4 _20146;
                    if (_6669)
                    {
                        float4 _18882 = _20133;
                        _18882.z = 0.0f;
                        _20146 = _18882;
                    }
                    else
                    {
                        _20146 = _20133;
                    }
                    bool _6681;
                    if (_6453)
                    {
                        uint _13523_dummy_parameter;
                        _6681 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19141 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13523_dummy_parameter))))), 0)).x) > _13496;
                    }
                    else
                    {
                        _6681 = _6453;
                    }
                    float4 _20178;
                    if (_6681)
                    {
                        float4 _18884 = _20146;
                        _18884.w = 0.0f;
                        _20178 = _18884;
                    }
                    else
                    {
                        _20178 = _20146;
                    }
                    _20177 = _20178;
                }
                else
                {
                    _20177 = _20133;
                }
                _20176 = _20177;
            }
            else
            {
                _20176 = _20133;
            }
            bool _6689 = _6435 != _6441;
            bool _6696;
            if (_6689)
            {
                _6696 = _6435 ? _6381 : _6384;
            }
            else
            {
                _6696 = _6689;
            }
            bool _6703;
            if (_6696)
            {
                _6703 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6703 = _6696;
            }
            float4 _20279;
            if (_6703)
            {
                bool2 _6708 = _6435.xx;
                float2 _6709 = float2(_6708.x ? _19137.x : _19139.x, _6708.y ? _19137.y : _19139.y);
                float _20160;
                if (_6435)
                {
                    uint _13543_dummy_parameter;
                    _20160 = r_depth_tm1.Load(int3(int2(floor(_6709 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13543_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13559_dummy_parameter;
                    _20160 = r_depth_tp1.Load(int3(int2(floor(_6709 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13559_dummy_parameter))))), 0)).x;
                }
                float4x4 _20167;
                if (_6435)
                {
                    float4x4 _20156;
                    do
                    {
                        float4x4 _13573;
                        bool _20155;
                        do
                        {
                            _13573 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20155 = false;
                                break;
                            }
                            uint _13607 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13607 + 32u) * 4 + 0) != 1u)
                            {
                                _20155 = false;
                                break;
                            }
                            uint _20152;
                            _20152 = 0u;
                            for (; _20152 < 4u; _20152++)
                            {
                                for (uint _20153 = 0u; _20153 < 4u; )
                                {
                                    _13573[_20152][_20153] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13607 + 16u) + (_20152 * 4u)) + _20153) * 4 + 0));
                                    _20153++;
                                    continue;
                                }
                            }
                            _20155 = true;
                            break;
                        } while(false);
                        if (_20155)
                        {
                            _20156 = _13573;
                            break;
                        }
                        _20156 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20167 = _20156;
                }
                else
                {
                    float4x4 _20151;
                    do
                    {
                        float4x4 _13679;
                        bool _20150;
                        do
                        {
                            _13679 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20150 = false;
                                break;
                            }
                            uint _13713 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13713 + 32u) * 4 + 0) != 1u)
                            {
                                _20150 = false;
                                break;
                            }
                            uint _20147;
                            _20147 = 0u;
                            for (; _20147 < 4u; _20147++)
                            {
                                for (uint _20148 = 0u; _20148 < 4u; )
                                {
                                    _13679[_20147][_20148] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13713 + (_20147 * 4u)) + _20148) * 4 + 0));
                                    _20148++;
                                    continue;
                                }
                            }
                            _20150 = true;
                            break;
                        } while(false);
                        if (_20150)
                        {
                            _20151 = _13679;
                            break;
                        }
                        _20151 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20167 = _20151;
                }
                float2 _20168;
                do
                {
                    float _13790 = _6709.x;
                    float _13793 = 1.0f - _6709.y;
                    float4 _13804 = mul(float4((float2(_13790, _13793) * 2.0f) - 1.0f.xx, _20160, 1.0f), _20167);
                    float _13806 = _13804.w;
                    if (!(_13806 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20168 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13819 = ((_13804.xy / _13806.xx) + 1.0f.xx) * 0.5f;
                    _20168 = float2(_13819.x - _13790, _13793 - _13819.y);
                    break;
                } while(false);
                float2 _6739 = float2(cbFI_DisplaySize);
                float4 _20280;
                if (!(length(((_6709 + _20168) - float2(_6708.x ? _19139.x : _19137.x, _6708.y ? _19139.y : _19137.y)) * _6739) <= ((0.100000001490116119384765625f * length(_20168 * _6739)) + 8.0f)))
                {
                    float4 _20281;
                    if (_6435)
                    {
                        float4 _18894 = _20176;
                        _18894.x = 0.0f;
                        _20281 = _18894;
                    }
                    else
                    {
                        float4 _18896 = _20176;
                        _18896.y = 0.0f;
                        _20281 = _18896;
                    }
                    _20280 = _20281;
                }
                else
                {
                    _20280 = _20176;
                }
                _20279 = _20280;
            }
            else
            {
                _20279 = _20176;
            }
            float4 _6764 = _19890 * _20279;
            float _6766 = dot(_6764, 1.0f.xxxx);
            float4 _20621;
            bool _20927;
            if (_6766 > 0.0f)
            {
                _20927 = _19581;
                _20621 = _6764 / _6766.xxxx;
            }
            else
            {
                bool _6777 = any(bool4(_20279.x < 1.0f.xxxx.x, _20279.y < 1.0f.xxxx.y, _20279.z < 1.0f.xxxx.z, _20279.w < 1.0f.xxxx.w));
                if (_6777)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13841;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13841);
                    }
                }
                bool4 _22864 = _6777.xxxx;
                _20927 = _6777 ? true : _19581;
                _20621 = float4(_22864.x ? 0.0f.xxxx.x : _19890.x, _22864.y ? 0.0f.xxxx.y : _19890.y, _22864.z ? 0.0f.xxxx.z : _19890.z, _22864.w ? 0.0f.xxxx.w : _19890.w);
            }
            _21098 = _21207;
            _20926 = _20927;
            _20620 = _20621;
        }
        else
        {
            _21098 = float3(0.0f, 0.0f, 0.5f);
            _20926 = _19581;
            _20620 = _19890;
        }
        uint _6786 = (cbFI_pad0 >> 24u) & 31u;
        uint _6790 = (cbFI_pad0 >> 16u) & 255u;
        bool _6792 = _6786 != 0u;
        bool _6794 = _6790 == 12u;
        bool _6797 = _6790 == 13u;
        float4 _20641;
        if ((_6792 || _6794) || _6797)
        {
            float _20287;
            do
            {
                bool _13925 = all(bool2(_19140.x > 0.0f.xx.x, _19140.y > 0.0f.xx.y));
                bool _13931;
                if (_13925)
                {
                    _13931 = all(bool2(_19140.x < 1.0f.xx.x, _19140.y < 1.0f.xx.y));
                }
                else
                {
                    _13931 = _13925;
                }
                bool _13862 = !_13931;
                bool _13869;
                if (!_13862)
                {
                    bool _13936 = all(bool2(_19141.x > 0.0f.xx.x, _19141.y > 0.0f.xx.y));
                    bool _13942;
                    if (_13936)
                    {
                        _13942 = all(bool2(_19141.x < 1.0f.xx.x, _19141.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13942 = _13936;
                    }
                    _13869 = !_13942;
                }
                else
                {
                    _13869 = _13862;
                }
                if (_13869)
                {
                    _20287 = 0.0f;
                    break;
                }
                uint _13949_dummy_parameter;
                uint _13965_dummy_parameter;
                float4x4 _20286;
                do
                {
                    float4x4 _13979;
                    bool _20285;
                    do
                    {
                        _13979 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20285 = false;
                            break;
                        }
                        uint _14013 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14013 + 32u) * 4 + 0) != 1u)
                        {
                            _20285 = false;
                            break;
                        }
                        uint _20282;
                        _20282 = 0u;
                        for (; _20282 < 4u; _20282++)
                        {
                            for (uint _20283 = 0u; _20283 < 4u; )
                            {
                                _13979[_20282][_20283] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14013 + 16u) + (_20282 * 4u)) + _20283) * 4 + 0));
                                _20283++;
                                continue;
                            }
                        }
                        _20285 = true;
                        break;
                    } while(false);
                    if (_20285)
                    {
                        _20286 = _13979;
                        break;
                    }
                    _20286 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13890 = mul(float4((float2(_19140.x, 1.0f - _19140.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19140 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13949_dummy_parameter))))), 0)).x, 1.0f), _20286);
                float _13892 = _13890.w;
                if (abs(_13892) < 9.9999999747524270787835121154785e-07f)
                {
                    _20287 = 0.0f;
                    break;
                }
                float _13903 = abs(cbFI_DeviceToViewDepth.y / ((_13890.z / _13892) - cbFI_DeviceToViewDepth.x));
                float _13906 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19141 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13965_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20287 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13903 - _13906) / max(max(_13903, _13906), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14115 = all(bool2(_19141.x > 0.0f.xx.x, _19141.y > 0.0f.xx.y));
            bool _14121;
            if (_14115)
            {
                _14121 = all(bool2(_19141.x < 1.0f.xx.x, _19141.y < 1.0f.xx.y));
            }
            else
            {
                _14121 = _14115;
            }
            float _20288;
            if (_14121)
            {
                uint _14128_dummy_parameter;
                _20288 = length((_7941 + (r_motion_tp1.Load(int3(int2(floor(_19141 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14128_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20288 = 1000000.0f;
            }
            float _20303;
            if ((_6786 & 1u) != 0u)
            {
                _20303 = _20287;
            }
            else
            {
                _20303 = 1.0f;
            }
            float _20304;
            if ((_6786 & 2u) != 0u)
            {
                _20304 = _20303 * (1.0f - smoothstep(2.0f, 8.0f, _20288));
            }
            else
            {
                _20304 = _20303;
            }
            float _20305;
            if ((_6786 & 4u) != 0u)
            {
                _20305 = _20304 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8662 - _8670) - length(_8646 - _8654))));
            }
            else
            {
                _20305 = _20304;
            }
            float _20635;
            if ((_6786 & 8u) != 0u)
            {
                _20635 = lerp(1.0f, _20305, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8646 - _8654)));
            }
            else
            {
                _20635 = _20305;
            }
            bool _6872 = (_6786 & 16u) != 0u;
            bool _6881;
            if (_6872)
            {
                _6881 = length(_19135 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6881 = _6872;
            }
            float _22866 = _6881 ? 1.0f : _20635;
            bool _6887 = _6792 && _11043;
            bool _6892;
            if (_6887)
            {
                bool _14153 = all(bool2(_19137.x > 0.0f.xx.x, _19137.y > 0.0f.xx.y));
                bool _14159;
                if (_14153)
                {
                    _14159 = all(bool2(_19137.x < 1.0f.xx.x, _19137.y < 1.0f.xx.y));
                }
                else
                {
                    _14159 = _14153;
                }
                _6892 = _14159;
            }
            else
            {
                _6892 = _6887;
            }
            bool _6897;
            if (_6892)
            {
                bool _14164 = all(bool2(_19139.x > 0.0f.xx.x, _19139.y > 0.0f.xx.y));
                bool _14170;
                if (_14164)
                {
                    _14170 = all(bool2(_19139.x < 1.0f.xx.x, _19139.y < 1.0f.xx.y));
                }
                else
                {
                    _14170 = _14164;
                }
                _6897 = _14170;
            }
            else
            {
                _6897 = _6892;
            }
            float4 _20642;
            if (_6897)
            {
                float _6903 = _20620.x + _20620.y;
                float _6912 = (_20620.z + _20620.w) * (1.0f - _22866);
                float _20638;
                if (_6903 > 9.9999997473787516355514526367188e-06f)
                {
                    _20638 = _20620.x / _6903;
                }
                else
                {
                    _20638 = _5642;
                }
                _20642 = float4(_20620.x + (_6912 * _20638), _20620.y + (_6912 * (1.0f - _20638)), _20620.zw * _22866);
            }
            else
            {
                _20642 = _20620;
            }
            _20641 = _20642;
        }
        else
        {
            _20641 = _20620;
        }
        float3 _6973 = (((_8646 * _20641.x) + (_8654 * _20641.y)) + (_8662 * _20641.z)) + (_8670 * _20641.w);
        float3 _22175;
        if (_5658 && (_20656 > 0.0f))
        {
            uint _14177_dummy_parameter;
            float2 _14192 = r_motion_tp1.Load(int3(int2(floor(_5417 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14177_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _20918;
            if (_7969)
            {
                float2 _14237 = clamp((((_19114 + (_14192 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14240 = tan(_14237.x);
                _20918 = (float2(_14240 / cbFI_DeviceToViewDepth.z, (tan(_14237.y) * sqrt(1.0f + (_14240 * _14240))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _20918 = _19114 + (_14192 * cbFI_Timestep);
            }
            float2 _20919;
            if (_7969)
            {
                float2 _14316 = clamp((((_19114 + (_14192 * _5632)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14319 = tan(_14316.x);
                _20919 = (float2(_14319 / cbFI_DeviceToViewDepth.z, (tan(_14316.y) * sqrt(1.0f + (_14319 * _14319))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _20919 = _19114 + (_14192 * _5632);
            }
            _22175 = lerp(_6973, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _20918, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _20919, 0.0f).xyz, cbFI_Timestep.xxx), _20656.xxx);
        }
        else
        {
            _22175 = _6973;
        }
        float3 _22174;
        if (_20926)
        {
            float3 _14361 = r_current_interpolation_source.Load(int3(_4905, 0)).xyz;
            float3 _22176;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11043)
            {
                uint _14368_dummy_parameter;
                float _21049;
                _21049 = r_depth_tm1.Load(int3(int2(floor(_19137 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14368_dummy_parameter))))), 0)).x;
                float _7054;
                for (int _21048 = 0; _21048 < 24; _21049 = _7054, _21048++)
                {
                    float _7026 = float(_21048 & 7) * 0.785398185253143310546875f;
                    int _7028 = _21048 >> 3;
                    int _22401;
                    if (_7028 == 0)
                    {
                        _22401 = 16;
                    }
                    else
                    {
                        _22401 = (_7028 == 1) ? 48 : 96;
                    }
                    uint _14388_dummy_parameter;
                    _7054 = max(_21049, r_depth_tm1.Load(int3(int2(floor(clamp(_19137 + ((cbFI_MvDepthLaneSizeRcp * float(_22401)) * float2(cos(_7026), sin(_7026))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14388_dummy_parameter))))), 0)).x);
                }
                float2 _21050;
                do
                {
                    float _14410 = 1.0f - _19137.y;
                    float4 _14421 = mul(float4((float2(_19137.x, _14410) * 2.0f) - 1.0f.xx, _21049, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14423 = _14421.w;
                    if (!(_14423 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21050 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14436 = ((_14421.xy / _14423.xx) + 1.0f.xx) * 0.5f;
                    _21050 = float2(_14436.x - _19137.x, _14410 - _14436.y);
                    break;
                } while(false);
                float2 _7065 = _19137 + _21050;
                bool _14454 = all(bool2(_7065.x > 0.0f.xx.x, _7065.y > 0.0f.xx.y));
                bool _14460;
                if (_14454)
                {
                    _14460 = all(bool2(_7065.x < 1.0f.xx.x, _7065.y < 1.0f.xx.y));
                }
                else
                {
                    _14460 = _14454;
                }
                float3 _22177;
                if (_14460)
                {
                    float _7071 = abs(cbFI_DeviceToViewDepth.y / (_21049 - cbFI_DeviceToViewDepth.x));
                    uint _14480_dummy_parameter;
                    int2 _14480 = int2(spvTextureSize(r_depth_m2, uint(0), _14480_dummy_parameter));
                    float _7075 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7065 * float2(_14480))), int2(0, 0), _14480 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22182;
                    if (abs(_7075 - _7071) <= (0.20000000298023223876953125f * max(_7075, _7071)))
                    {
                        uint _14514_dummy_parameter;
                        int2 _14514 = int2(spvTextureSize(r_colour_m2, uint(0), _14514_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14537;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14537);
                        }
                        _22182 = r_colour_m2.Load(int3(clamp(int2(floor(_7065 * float2(_14514))), int2(0, 0), _14514 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14547;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14547);
                        }
                        _22182 = _14361;
                    }
                    _22177 = _22182;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14557;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14557);
                    }
                    _22177 = _14361;
                }
                _22176 = _22177;
            }
            else
            {
                _22176 = _14361;
            }
            _22174 = _22176;
        }
        else
        {
            _22174 = _22175;
        }
        bool _7100 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22173;
        float _22249;
        if (_7100)
        {
            float _14743;
            float2 _7104 = float2(cbFI_DisplaySize);
            float3 _21089;
            do
            {
                bool _14804;
                float4x4 _21057;
                do
                {
                    float4x4 _14780;
                    bool _21056;
                    do
                    {
                        _14780 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14804 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14804)
                        {
                            _21056 = false;
                            break;
                        }
                        uint _14814 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14814 + 32u) * 4 + 0) != 1u)
                        {
                            _21056 = false;
                            break;
                        }
                        uint _21053;
                        _21053 = 0u;
                        for (; _21053 < 4u; _21053++)
                        {
                            for (uint _21054 = 0u; _21054 < 4u; )
                            {
                                _14780[_21053][_21054] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14814 + (_21053 * 4u)) + _21054) * 4 + 0));
                                _21054++;
                                continue;
                            }
                        }
                        _21056 = true;
                        break;
                    } while(false);
                    if (_21056)
                    {
                        _21057 = _14780;
                        break;
                    }
                    _21057 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float _14891;
                float _14894;
                float4 _14904;
                float4x4 _14611 = spvInverse(_21057);
                float2 _21058;
                do
                {
                    _14891 = _5417.x;
                    _14894 = 1.0f - _5417.y;
                    _14904 = float4((float2(_14891, _14894) * 2.0f) - 1.0f.xx, 0.99999988079071044921875f, 1.0f);
                    float4 _14905 = mul(_14904, _21057);
                    float _14907 = _14905.w;
                    if (!(_14907 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21058 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14920 = ((_14905.xy / _14907.xx) + 1.0f.xx) * 0.5f;
                    _21058 = float2(_14920.x - _14891, _14894 - _14920.y);
                    break;
                } while(false);
                float2 _21059;
                do
                {
                    float4 _14957 = mul(_14904, _14611);
                    float _14959 = _14957.w;
                    if (!(_14959 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21059 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14972 = ((_14957.xy / _14959.xx) + 1.0f.xx) * 0.5f;
                    _21059 = float2(_14972.x - _14891, _14894 - _14972.y);
                    break;
                } while(false);
                float2 _14619 = abs(_21058);
                bool2 _22867 = any(bool2(_14619.x > 4.0f.xx.x, _14619.y > 4.0f.xx.y)).xx;
                float2 _14625 = abs(_21059);
                bool2 _22869 = any(bool2(_14625.x > 4.0f.xx.x, _14625.y > 4.0f.xx.y)).xx;
                float2 _14986[3];
                _14986[0] = _5417;
                float2 _15106 = clamp(_5417, 0.0f.xx, 1.0f.xx);
                uint _15114_dummy_parameter;
                _14986[1] = _5417 - ((r_motion_tp1.Load(int3(int2(floor(_15106 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15114_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5642);
                _14986[2] = _5417 - (float2(_22867.x ? 0.0f.xx.x : _21058.x, _22867.y ? 0.0f.xx.y : _21058.y) * _5642);
                float _21065;
                float2 _21066;
                _21066 = _5417;
                _21065 = 1000000000.0f;
                float _22871;
                float2 _22873;
                float _22874;
                int _21064 = 0;
                float _22393 = -1.0f;
                for (; _21064 < 3; _22393 = _22871, _21066 = _22873, _21065 = _22874, _21064++)
                {
                    float2 _22383;
                    _22383 = _14986[_21064];
                    for (int _22382 = 0; _22382 < 30; )
                    {
                        uint _15628_dummy_parameter;
                        _22383 += (((_5417 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_22383, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15628_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5642)) - _22383) * 0.699999988079071044921875f);
                        _22382++;
                        continue;
                    }
                    float2 _16058 = clamp(_22383, 0.0f.xx, 1.0f.xx);
                    uint _16066_dummy_parameter;
                    bool _16496 = all(bool2(_22383.x > 0.0f.xx.x, _22383.y > 0.0f.xx.y));
                    bool _16502;
                    if (_16496)
                    {
                        _16502 = all(bool2(_22383.x < 1.0f.xx.x, _22383.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _16502 = _16496;
                    }
                    float _22385;
                    if (_16502)
                    {
                        _22385 = length(((_22383 + ((r_motion_tp1.Load(int3(int2(floor(_16058 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16066_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5642)) - _5417) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22385 = 1000000000.0f;
                    }
                    uint _16513_dummy_parameter;
                    float _16553 = log(((r_depth_tp1.Load(int3(int2(floor(_16058 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16513_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15066 = _22385 < 0.3499999940395355224609375f;
                    bool _15068 = _21065 < 0.3499999940395355224609375f;
                    bool _15078;
                    if (_15066)
                    {
                        _15078 = (!_15068) || (_16553 > _22393);
                    }
                    else
                    {
                        _15078 = _15066;
                    }
                    bool _15091;
                    if (!_15078)
                    {
                        _15091 = ((!_15066) && (!_15068)) && (_22385 < _21065);
                    }
                    else
                    {
                        _15091 = _15078;
                    }
                    _22871 = _15091 ? _16553 : _22393;
                    bool2 _22872 = _15091.xx;
                    _22873 = float2(_22872.x ? _22383.x : _21066.x, _22872.y ? _22383.y : _21066.y);
                    _22874 = _15091 ? _22385 : _21065;
                }
                float2 _16555[3];
                _16555[0] = _5417;
                float2 _21085;
                do
                {
                    bool _21075;
                    do
                    {
                        bool _16802 = all(bool2(_15106.x > 0.0f.xx.x, _15106.y > 0.0f.xx.y));
                        bool _16808;
                        if (_16802)
                        {
                            _16808 = all(bool2(_15106.x < 1.0f.xx.x, _15106.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _16808 = _16802;
                        }
                        if (!_16808)
                        {
                            _21075 = false;
                            break;
                        }
                        uint _16815_dummy_parameter;
                        float4x4 _21073;
                        do
                        {
                            float4x4 _16829;
                            bool _21072;
                            do
                            {
                                _16829 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14804)
                                {
                                    _21072 = false;
                                    break;
                                }
                                uint _16863 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_16863 + 32u) * 4 + 0) != 1u)
                                {
                                    _21072 = false;
                                    break;
                                }
                                uint _21069;
                                _21069 = 0u;
                                for (; _21069 < 4u; _21069++)
                                {
                                    for (uint _21070 = 0u; _21070 < 4u; )
                                    {
                                        _16829[_21069][_21070] = asfloat(rw_nfru_diagnostics.Load<uint>(((_16863 + (_21069 * 4u)) + _21070) * 4 + 0));
                                        _21070++;
                                        continue;
                                    }
                                }
                                _21072 = true;
                                break;
                            } while(false);
                            if (_21072)
                            {
                                _21073 = _16829;
                                break;
                            }
                            _21073 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21074;
                        do
                        {
                            float _16940 = _15106.x;
                            float _16943 = 1.0f - _15106.y;
                            float4 _16954 = mul(float4((float2(_16940, _16943) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15106 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16815_dummy_parameter))))), 0)).x, 1.0f), _21073);
                            float _16956 = _16954.w;
                            if (!(_16956 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21074 = 1000000.0f.xx;
                                break;
                            }
                            float2 _16969 = ((_16954.xy / _16956.xx) + 1.0f.xx) * 0.5f;
                            _21074 = float2(_16969.x - _16940, _16943 - _16969.y);
                            break;
                        } while(false);
                        float2 _16766 = abs(_21074);
                        if (any(bool2(_16766.x > 100000.0f.xx.x, _16766.y > 100000.0f.xx.y)))
                        {
                            _21075 = false;
                            break;
                        }
                        float _16774 = length(_21074 * _7104);
                        uint _16989_dummy_parameter;
                        bool _16788 = _16774 > ((8.0f * _7104.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _16795;
                        if (_16788)
                        {
                            _16795 = length((r_motion_tp1.Load(int3(int2(floor(_15106 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16989_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7104) < (0.20000000298023223876953125f * _16774);
                        }
                        else
                        {
                            _16795 = _16788;
                        }
                        _21075 = _16795;
                        break;
                    } while(false);
                    if (_21075)
                    {
                        uint _17020_dummy_parameter;
                        _21085 = -(r_motion_tp1.Load(int3(int2(floor(_15106 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17020_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17047_dummy_parameter;
                    float2 _21084;
                    do
                    {
                        float _17066 = _15106.x;
                        float _17069 = 1.0f - _15106.y;
                        float4 _17080 = mul(float4((float2(_17066, _17069) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15106 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17047_dummy_parameter))))), 0)).x, 1.0f), _14611);
                        float _17082 = _17080.w;
                        if (!(_17082 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21084 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17095 = ((_17080.xy / _17082.xx) + 1.0f.xx) * 0.5f;
                        _21084 = float2(_17095.x - _17066, _17069 - _17095.y);
                        break;
                    } while(false);
                    float2 _16733 = abs(_21084);
                    bool2 _16737 = any(bool2(_16733.x > 4.0f.xx.x, _16733.y > 4.0f.xx.y)).xx;
                    _21085 = float2(_16737.x ? 0.0f.xx.x : _21084.x, _16737.y ? 0.0f.xx.y : _21084.y);
                    break;
                } while(false);
                _16555[1] = _5417 - (_21085 * cbFI_Timestep);
                _16555[2] = _5417 - (float2(_22869.x ? 0.0f.xx.x : _21059.x, _22869.y ? 0.0f.xx.y : _21059.y) * cbFI_Timestep);
                float _21087;
                float2 _21088;
                _21088 = _5417;
                _21087 = 1000000000.0f;
                float _22875;
                float2 _22877;
                float _22878;
                float4x4 _17343;
                float4x4 _17781;
                int _21086 = 0;
                float _22320 = -1.0f;
                for (; _21086 < 3; _22320 = _22875, _21088 = _22877, _21087 = _22878, _21086++)
                {
                    float2 _22270;
                    _22270 = _16555[_21086];
                    float2 _17152;
                    for (int _22269 = 0; _22269 < 30; _22270 = _17152, _22269++)
                    {
                        float2 _22361;
                        do
                        {
                            float2 _17232 = clamp(_22270, 0.0f.xx, 1.0f.xx);
                            bool _22351;
                            do
                            {
                                bool _17316 = all(bool2(_17232.x > 0.0f.xx.x, _17232.y > 0.0f.xx.y));
                                bool _17322;
                                if (_17316)
                                {
                                    _17322 = all(bool2(_17232.x < 1.0f.xx.x, _17232.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17322 = _17316;
                                }
                                if (!_17322)
                                {
                                    _22351 = false;
                                    break;
                                }
                                uint _17329_dummy_parameter;
                                float4x4 _22349;
                                do
                                {
                                    bool _22348;
                                    do
                                    {
                                        _17343 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14804)
                                        {
                                            _22348 = false;
                                            break;
                                        }
                                        uint _17377 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17377 + 32u) * 4 + 0) != 1u)
                                        {
                                            _22348 = false;
                                            break;
                                        }
                                        uint _22345;
                                        _22345 = 0u;
                                        for (; _22345 < 4u; _22345++)
                                        {
                                            for (uint _22346 = 0u; _22346 < 4u; )
                                            {
                                                _17343[_22345][_22346] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17377 + (_22345 * 4u)) + _22346) * 4 + 0));
                                                _22346++;
                                                continue;
                                            }
                                        }
                                        _22348 = true;
                                        break;
                                    } while(false);
                                    if (_22348)
                                    {
                                        _22349 = _17343;
                                        break;
                                    }
                                    _22349 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _22350;
                                do
                                {
                                    float _17454 = _17232.x;
                                    float _17457 = 1.0f - _17232.y;
                                    float4 _17468 = mul(float4((float2(_17454, _17457) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17232 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17329_dummy_parameter))))), 0)).x, 1.0f), _22349);
                                    float _17470 = _17468.w;
                                    if (!(_17470 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _22350 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _17483 = ((_17468.xy / _17470.xx) + 1.0f.xx) * 0.5f;
                                    _22350 = float2(_17483.x - _17454, _17457 - _17483.y);
                                    break;
                                } while(false);
                                float2 _17280 = abs(_22350);
                                if (any(bool2(_17280.x > 100000.0f.xx.x, _17280.y > 100000.0f.xx.y)))
                                {
                                    _22351 = false;
                                    break;
                                }
                                float _17288 = length(_22350 * _7104);
                                uint _17503_dummy_parameter;
                                bool _17302 = _17288 > ((8.0f * _7104.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17309;
                                if (_17302)
                                {
                                    _17309 = length((r_motion_tp1.Load(int3(int2(floor(_17232 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17503_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7104) < (0.20000000298023223876953125f * _17288);
                                }
                                else
                                {
                                    _17309 = _17302;
                                }
                                _22351 = _17309;
                                break;
                            } while(false);
                            if (_22351)
                            {
                                uint _17534_dummy_parameter;
                                _22361 = -(r_motion_tp1.Load(int3(int2(floor(_17232 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17534_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _17561_dummy_parameter;
                            float2 _22360;
                            do
                            {
                                float _17580 = _17232.x;
                                float _17583 = 1.0f - _17232.y;
                                float4 _17594 = mul(float4((float2(_17580, _17583) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17232 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17561_dummy_parameter))))), 0)).x, 1.0f), _14611);
                                float _17596 = _17594.w;
                                if (!(_17596 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22360 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17609 = ((_17594.xy / _17596.xx) + 1.0f.xx) * 0.5f;
                                _22360 = float2(_17609.x - _17580, _17583 - _17609.y);
                                break;
                            } while(false);
                            float2 _17247 = abs(_22360);
                            bool2 _17251 = any(bool2(_17247.x > 4.0f.xx.x, _17247.y > 4.0f.xx.y)).xx;
                            _22361 = float2(_17251.x ? 0.0f.xx.x : _22360.x, _17251.y ? 0.0f.xx.y : _22360.y);
                            break;
                        } while(false);
                        _17152 = _22270 + (((_5417 - (_22361 * cbFI_Timestep)) - _22270) * 0.699999988079071044921875f);
                    }
                    float2 _17670;
                    float2 _22287;
                    do
                    {
                        _17670 = clamp(_22270, 0.0f.xx, 1.0f.xx);
                        bool _22277;
                        do
                        {
                            bool _17754 = all(bool2(_17670.x > 0.0f.xx.x, _17670.y > 0.0f.xx.y));
                            bool _17760;
                            if (_17754)
                            {
                                _17760 = all(bool2(_17670.x < 1.0f.xx.x, _17670.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _17760 = _17754;
                            }
                            if (!_17760)
                            {
                                _22277 = false;
                                break;
                            }
                            uint _17767_dummy_parameter;
                            float4x4 _22275;
                            do
                            {
                                bool _22274;
                                do
                                {
                                    _17781 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14804)
                                    {
                                        _22274 = false;
                                        break;
                                    }
                                    uint _17815 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_17815 + 32u) * 4 + 0) != 1u)
                                    {
                                        _22274 = false;
                                        break;
                                    }
                                    uint _22271;
                                    _22271 = 0u;
                                    for (; _22271 < 4u; _22271++)
                                    {
                                        for (uint _22272 = 0u; _22272 < 4u; )
                                        {
                                            _17781[_22271][_22272] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17815 + (_22271 * 4u)) + _22272) * 4 + 0));
                                            _22272++;
                                            continue;
                                        }
                                    }
                                    _22274 = true;
                                    break;
                                } while(false);
                                if (_22274)
                                {
                                    _22275 = _17781;
                                    break;
                                }
                                _22275 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _22276;
                            do
                            {
                                float _17895 = 1.0f - _17670.y;
                                float4 _17906 = mul(float4((float2(_17670.x, _17895) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17670 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17767_dummy_parameter))))), 0)).x, 1.0f), _22275);
                                float _17908 = _17906.w;
                                if (!(_17908 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22276 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17921 = ((_17906.xy / _17908.xx) + 1.0f.xx) * 0.5f;
                                _22276 = float2(_17921.x - _17670.x, _17895 - _17921.y);
                                break;
                            } while(false);
                            float2 _17718 = abs(_22276);
                            if (any(bool2(_17718.x > 100000.0f.xx.x, _17718.y > 100000.0f.xx.y)))
                            {
                                _22277 = false;
                                break;
                            }
                            float _17726 = length(_22276 * _7104);
                            uint _17941_dummy_parameter;
                            bool _17740 = _17726 > ((8.0f * _7104.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _17747;
                            if (_17740)
                            {
                                _17747 = length((r_motion_tp1.Load(int3(int2(floor(_17670 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17941_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7104) < (0.20000000298023223876953125f * _17726);
                            }
                            else
                            {
                                _17747 = _17740;
                            }
                            _22277 = _17747;
                            break;
                        } while(false);
                        if (_22277)
                        {
                            uint _17972_dummy_parameter;
                            _22287 = -(r_motion_tp1.Load(int3(int2(floor(_17670 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17972_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _17999_dummy_parameter;
                        float2 _22286;
                        do
                        {
                            float _18021 = 1.0f - _17670.y;
                            float4 _18032 = mul(float4((float2(_17670.x, _18021) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17670 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17999_dummy_parameter))))), 0)).x, 1.0f), _14611);
                            float _18034 = _18032.w;
                            if (!(_18034 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22286 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18047 = ((_18032.xy / _18034.xx) + 1.0f.xx) * 0.5f;
                            _22286 = float2(_18047.x - _17670.x, _18021 - _18047.y);
                            break;
                        } while(false);
                        float2 _17685 = abs(_22286);
                        bool2 _17689 = any(bool2(_17685.x > 4.0f.xx.x, _17685.y > 4.0f.xx.y)).xx;
                        _22287 = float2(_17689.x ? 0.0f.xx.x : _22286.x, _17689.y ? 0.0f.xx.y : _22286.y);
                        break;
                    } while(false);
                    bool _18065 = all(bool2(_22270.x > 0.0f.xx.x, _22270.y > 0.0f.xx.y));
                    bool _18071;
                    if (_18065)
                    {
                        _18071 = all(bool2(_22270.x < 1.0f.xx.x, _22270.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18071 = _18065;
                    }
                    float _22299;
                    if (_18071)
                    {
                        _22299 = length(((_22270 + (_22287 * cbFI_Timestep)) - _5417) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22299 = 1000000000.0f;
                    }
                    uint _18098_dummy_parameter;
                    float _18122 = log(((r_depth_tm1.Load(int3(int2(floor(_17670 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18098_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _16635 = _22299 < 0.3499999940395355224609375f;
                    bool _16637 = _21087 < 0.3499999940395355224609375f;
                    bool _16647;
                    if (_16635)
                    {
                        _16647 = (!_16637) || (_18122 > _22320);
                    }
                    else
                    {
                        _16647 = _16635;
                    }
                    bool _16660;
                    if (!_16647)
                    {
                        _16660 = ((!_16635) && (!_16637)) && (_22299 < _21087);
                    }
                    else
                    {
                        _16660 = _16647;
                    }
                    _22875 = _16660 ? _18122 : _22320;
                    bool2 _22876 = _16660.xx;
                    _22877 = float2(_22876.x ? _22270.x : _21088.x, _22876.y ? _22270.y : _21088.y);
                    _22878 = _16660 ? _22299 : _21087;
                }
                float3 _18131 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21066, 0.0f).xyz;
                float3 _18139 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21088, 0.0f).xyz;
                uint _18146_dummy_parameter;
                uint _18177_dummy_parameter;
                float _14665 = exp((_21065 * (-2.0f)) * (_21065 * 2.0f));
                float _14672 = exp((_21087 * (-2.0f)) * (_21087 * 2.0f));
                float _14685 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21088, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18177_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21066, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18146_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14699 = ((_14665 * cbFI_Timestep) * ((1.0f - _14672) + ((_14672 * 2.0f) * _14685))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14709 = 1.0f - _14685;
                float _14716 = ((_14672 * _5642) * ((1.0f - _14665) + ((_14665 * 2.0f) * _14709))) + (9.9999997473787516355514526367188e-05f * _5642);
                float _14725 = (((_14665 * _14672) * 4.0f) * _14685) * _14709;
                _14743 = (_14725 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18139 - _18131, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14725)) * max(_14665, _14672));
                if (_6790 == 30u)
                {
                    _21089 = _18131;
                    break;
                }
                if (_6790 == 31u)
                {
                    _21089 = _18139;
                    break;
                }
                if (_6790 == 32u)
                {
                    _21089 = float3(_14665, _14672, _14685);
                    break;
                }
                _21089 = ((_18131 * _14699) + (_18139 * _14716)) / (_14699 + _14716).xxx;
                break;
            } while(false);
            _22249 = _14743;
            _22173 = _21089;
        }
        else
        {
            _22249 = 1.0f;
            _22173 = _22174;
        }
        uint _7120 = cbFI_pad0 & 255u;
        bool _22025;
        float3 _22172;
        if (_7120 != 0u)
        {
            float3 _7125 = r_present_backbuffer.Load(int3(_4905, 0)).xyz;
            float3 _7129 = r_current_interpolation_source.Load(int3(_4905, 0)).xyz;
            float3 _7133 = abs(_7125 - _7129);
            float3 _21090;
            if (_7120 == 2u)
            {
                _21090 = (abs(_7129) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21090 = 0.000244140625f.xxx;
            }
            bool _7149 = any(bool3(_7133.x > _21090.x, _7133.y > _21090.y, _7133.z > _21090.z));
            bool3 _22879 = _7149.xxx;
            _22172 = float3(_22879.x ? _7125.x : _22173.x, _22879.y ? _7125.y : _22173.y, _22879.z ? _7125.z : _22173.z);
            _22025 = _7149;
        }
        else
        {
            _22172 = _22173;
            _22025 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18215;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18215);
        }
        float3 _22154;
        if (_6790 == 1u)
        {
            _22154 = lerp(_8646, _8654, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22155;
            if (_6790 == 2u)
            {
                _22155 = lerp(_8662, _8670, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22156;
                if (_6790 == 3u)
                {
                    _22156 = float(_22025).xxx;
                }
                else
                {
                    float3 _22157;
                    if (_6790 == 4u)
                    {
                        _22157 = float3(((_19135 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22158;
                        if (_6790 == 5u)
                        {
                            _22158 = float3(((_7941 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22159;
                            if (_6790 == 6u)
                            {
                                _22159 = float3(_20641.xy, _20641.z + _20641.w);
                            }
                            else
                            {
                                float3 _22160;
                                if (_6790 == 7u)
                                {
                                    _22160 = r_current_interpolation_source.Load(int3(_4905, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22161;
                                    if (_6790 == 8u)
                                    {
                                        _22161 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5417, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22162;
                                        if (_6794)
                                        {
                                            uint _18237_dummy_parameter;
                                            uint _18269_dummy_parameter;
                                            _22162 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_5417 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18237_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_5417 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18269_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22163;
                                            if (_6797)
                                            {
                                                _22163 = _8662;
                                            }
                                            else
                                            {
                                                float3 _22164;
                                                if (_6790 == 20u)
                                                {
                                                    _22164 = _8646;
                                                }
                                                else
                                                {
                                                    float3 _22165;
                                                    if (_6790 == 21u)
                                                    {
                                                        _22165 = _8654;
                                                    }
                                                    else
                                                    {
                                                        float3 _22166;
                                                        if (_6790 == 22u)
                                                        {
                                                            _22166 = _8670;
                                                        }
                                                        else
                                                        {
                                                            float3 _22167;
                                                            if (_6790 == 18u)
                                                            {
                                                                _22167 = _21608;
                                                            }
                                                            else
                                                            {
                                                                float3 _22168;
                                                                if (_6790 == 19u)
                                                                {
                                                                    _22168 = _21350;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22169;
                                                                    if (_6790 == 23u)
                                                                    {
                                                                        _22169 = _21098;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22170;
                                                                        if (_6790 == 24u)
                                                                        {
                                                                            uint _7293 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7298 = float(rw_nfru_diagnostics.Load<uint>((_7293 + 35u) * 4 + 0));
                                                                            float _21091;
                                                                            if (_7298 > 0.0f)
                                                                            {
                                                                                _21091 = float(rw_nfru_diagnostics.Load<uint>((_7293 + 34u) * 4 + 0)) / _7298;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21091 = 0.0f;
                                                                            }
                                                                            _22170 = float3(float(rw_nfru_diagnostics.Load<uint>((_7293 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7293 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21091);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22170 = _22172;
                                                                        }
                                                                        _22169 = _22170;
                                                                    }
                                                                    _22168 = _22169;
                                                                }
                                                                _22167 = _22168;
                                                            }
                                                            _22166 = _22167;
                                                        }
                                                        _22165 = _22166;
                                                    }
                                                    _22164 = _22165;
                                                }
                                                _22163 = _22164;
                                            }
                                            _22162 = _22163;
                                        }
                                        _22161 = _22162;
                                    }
                                    _22160 = _22161;
                                }
                                _22159 = _22160;
                            }
                            _22158 = _22159;
                        }
                        _22157 = _22158;
                    }
                    _22156 = _22157;
                }
                _22155 = _22156;
            }
            _22154 = _22155;
        }
        float3 _22153;
        if ((_6790 >= 9u) && (_6790 <= 11u))
        {
            uint _7358 = 64u + uint((_19358.y * cbFI_MvDepthLaneSize.x) + _19358.x);
            uint _7362 = rw_nfru_diagnostics.Load<uint>(_7358 * 4 + 0) & 15u;
            float3 _22187;
            if (_6790 == 10u)
            {
                float3 _22152;
                if ((rw_nfru_diagnostics.Load<uint>(_7358 * 4 + 0) & 32u) != 0u)
                {
                    _22152 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22151;
                    if ((rw_nfru_diagnostics.Load<uint>(_7358 * 4 + 0) & 16u) != 0u)
                    {
                        _22151 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7383 = ((rw_nfru_diagnostics.Load<uint>(_7358 * 4 + 0) & 64u) != 0u).xxx;
                        _22151 = float3(_7383.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7383.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7383.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22152 = _22151;
                }
                _22187 = _22152;
            }
            else
            {
                float3 _22188;
                if (_6790 == 11u)
                {
                    uint _7396 = (rw_nfru_diagnostics.Load<uint>(_7358 * 4 + 0) >> 8u) & 15u;
                    uint _7399 = (rw_nfru_diagnostics.Load<uint>(_7358 * 4 + 0) >> 12u) & 15u;
                    float3 _22144;
                    if ((_7362 == 2u) || (_7362 == 3u))
                    {
                        _22144 = _4587[_7362];
                    }
                    else
                    {
                        bool _7411 = _7396 == 3u;
                        bool _7413 = _7399 == 3u;
                        float3 _22145;
                        if (_7411 && _7413)
                        {
                            _22145 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22146;
                            if (_7411)
                            {
                                _22146 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22147;
                                if (_7413)
                                {
                                    _22147 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22148;
                                    if ((_7396 == 4u) || (_7399 == 4u))
                                    {
                                        _22148 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22149;
                                        if ((_7396 == 1u) || (_7399 == 1u))
                                        {
                                            _22149 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _22881 = (_7362 == 1u).xxx;
                                            _22149 = float3(_22881.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _22881.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _22881.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22148 = _22149;
                                    }
                                    _22147 = _22148;
                                }
                                _22146 = _22147;
                            }
                            _22145 = _22146;
                        }
                        _22144 = _22145;
                    }
                    _22188 = _22144;
                }
                else
                {
                    _22188 = _4587[min(_7362, 7u)];
                }
                _22187 = _22188;
            }
            _22153 = _22187;
        }
        else
        {
            _22153 = _22154;
        }
        float4 _22191;
        if ((_6790 >= 14u) && (_6790 <= 16u))
        {
            float2 _22189;
            if (_6790 == 14u)
            {
                uint _7469_dummy_parameter;
                uint _7475_dummy_parameter;
                _22189 = r_flow_tm1.Load(int3(clamp(int2(floor(_5417 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7469_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7475_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22190;
                if (_6790 == 16u)
                {
                    uint _18345 = r_warped_flow_qdata_tm1.Load(int3(_5433, 0)).x & 2147483647u;
                    uint _18377 = uint(max((int((_18345 >> 16u) & 15u) - 6), 0));
                    _22190 = ((float2(float((1 - (2 * int((_18345 >> 15u) & 1u))) * int(((_18345 >> uint(7)) & 127u) << _18377)), float((1 - (2 * int((_18345 >> 14u) & 1u))) * int((_18345 & 127u) << _18377))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22190 = _7941 * float2(cbFI_DisplaySize);
                }
                _22189 = _22190;
            }
            uint2 _7508 = uint2(clamp(round(_22189 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7510 = _7508.x;
            uint _7517 = _7508.y;
            _22191 = float4(float(_7510 & 255u), float((_7510 >> 8u) | ((_7517 & 15u) << 4u)), float(_7517 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22192;
            if (_6790 == 17u)
            {
                _22192 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5433, 0)).x != 0u), _5877, 0.0f, 1.0f);
            }
            else
            {
                _22192 = float4(_22153, 1.0f);
            }
            _22191 = _22192;
        }
        rw_output[_4905] = _22191.xyz;
        if (_7100)
        {
            uint _18422 = uint((_4905.y * cbFI_DisplaySize.x) + _4905.x) * 2u;
            rw_nfru_select.Store<uint>(_18422 * 4 + 0, spvPackHalf2x16(_22191.xy));
            rw_nfru_select.Store<uint>((_18422 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22191.z, (_22025 || (_6790 != 0u)) ? 2.0f : _22249)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7575 = ((uint(_4905.y) * uint(cbFI_DisplaySize.x)) + uint(_4905.x)) * 6u;
            uint _18448 = spvPackHalf2x16(clamp(_8645.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7575 * 4 + 0, (((_18448 & 32767u) >> 4u) | ((((_18448 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8645.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18483 = spvPackHalf2x16(clamp(_8653.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7575 + 1u) * 4 + 0, (((_18483 & 32767u) >> 4u) | ((((_18483 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8653.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18518 = spvPackHalf2x16(clamp(_8661.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7575 + 2u) * 4 + 0, (((_18518 & 32767u) >> 4u) | ((((_18518 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8661.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18553 = spvPackHalf2x16(clamp(_8669.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7575 + 3u) * 4 + 0, (((_18553 & 32767u) >> 4u) | ((((_18553 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8669.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _18580 = r_current_interpolation_source.Load(int3(_4905, 0));
            uint _18594 = spvPackHalf2x16(clamp(_18580.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7575 + 4u) * 4 + 0, (((_18594 & 32767u) >> 4u) | ((((_18594 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_18580.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _22268;
            if (_22025 || (_6790 != 0u))
            {
                _22268 = 4294967295u;
            }
            else
            {
                uint _18629 = spvPackHalf2x16(clamp(_22191.xy, 0.0f.xx, 65000.0f.xx));
                _22268 = (((_18629 & 32767u) >> 4u) | ((((_18629 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22191.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7575 + 5u) * 4 + 0, _22268);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4905] = float4(r_current_interpolation_source.Load(int3(_4905, 0)).xyz, 1.0f).xyz;
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
