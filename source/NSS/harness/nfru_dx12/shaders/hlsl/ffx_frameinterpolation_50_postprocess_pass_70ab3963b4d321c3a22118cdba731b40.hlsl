static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19030;

static const int2 _1243[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1252[5] = { 2, 4, 7, 11, 16 };
static const float3 _4568[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4869 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4869.x >= cbFI_DisplaySize.x, _4869.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4869] = float4(r_present_backbuffer.Load(int3(_4869, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7722 = cbFI_DisplaySize - int2(1, 1);
                int2 _7723 = clamp(_4869, int2(0, 0), _7722);
                uint _7733 = uint((_7723.y * cbFI_DisplaySize.x) + _7723.x) * 2u;
                uint _7736 = rw_nfru_select.Load<uint>(_7733 * 4 + 0);
                float2 _7737 = spvUnpackHalf2x16(_7736);
                uint _7741 = rw_nfru_select.Load<uint>((_7733 + 1u) * 4 + 0);
                float2 _7742 = spvUnpackHalf2x16(_7741);
                float _7743 = _7737.x;
                float _7745 = _7742.x;
                if (_7742.y > 1.5f)
                {
                    rw_output[_4869] = float4(_7743, _7737.y, _7745, 1.0f).xyz;
                    break;
                }
                int _22359;
                float _22360;
                float3 _22361;
                float _22362;
                float _22363;
                _22363 = 0.0f;
                _22362 = 0.0f;
                _22361 = 0.0f.xxx;
                _22360 = 0.0f;
                _22359 = -2;
                float3 _22366;
                float _22367;
                float _22368;
                float _22369;
                for (; _22359 <= 2; _22363 = _22369, _22362 = _22368, _22361 = _22366, _22360 = _22367, _22359++)
                {
                    _22369 = _22363;
                    _22368 = _22362;
                    _22367 = _22360;
                    _22366 = _22361;
                    for (int _22364 = -2; _22364 <= 2; )
                    {
                        float _7639 = float((_22364 * _22364) + (_22359 * _22359));
                        float _7644 = exp(_7639 * (-0.319999992847442626953125f));
                        int2 _7649 = int2(_22364, _22359);
                        int2 _7759 = clamp(_4869 + (_7649 * int2(2, 2)), int2(0, 0), _7722);
                        uint _7769 = uint((_7759.y * cbFI_DisplaySize.x) + _7759.x) * 2u;
                        float _7666 = exp(_7639 * (-0.5f));
                        int2 _7791 = clamp(_4869 + (_7649 * int2(6, 6)), int2(0, 0), _7722);
                        _22369 += _7666;
                        _22368 += (_7666 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7791.y * cbFI_DisplaySize.x) + _7791.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _22367 += _7644;
                        _22366 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7769 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7769 + 1u) * 4 + 0)).x, _19030).xyz * _7644);
                        _22364++;
                        continue;
                    }
                }
                float3 _7696 = _22361 / _22360.xxx;
                rw_output[_4869] = float4(_7696 + ((float4(_7743, _7737.y, _7745, _7742.y).xyz - _7696) * clamp(_22362 / _22363, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5368 = (float2(_4869) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5370 = float2(cbFI_MvDepthLaneSize);
        int2 _5379 = int2(floor(_5368 * _5370));
        int2 _5384 = int2(floor(_5368 * float2(cbFI_FlowLaneSize)));
        float4 _7862 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5368 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7868 = r_warped_filled_flow_tm1.Load(int3(_5384, 0)).xy;
        float2 _7874 = r_warped_filled_motion_tp1.Load(int3(_5379, 0)).xy;
        bool _7896 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19031;
        if (_7896)
        {
            float _7909 = ((2.0f * _5368.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19031 = float2(atan(_7909) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5368.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7909 * _7909))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19031 = _5368;
        }
        bool _5405 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19052;
        bool _19194;
        int2 _19275;
        float3 _21525;
        if (_5405)
        {
            float _19033;
            float _19035;
            _19035 = 2.0f;
            _19033 = -1.0f;
            uint _4966[9];
            float _22370;
            float _22373;
            for (int _19032 = 0; _19032 < 9; _19035 = _22373, _19033 = _22370, _19032++)
            {
                _4966[_19032] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5379 + int2((_19032 % 3) - 1, (_19032 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4966[_19032] != 0u)
                {
                    float _22354;
                    if (_4966[_19032] == 0u)
                    {
                        _22354 = -1.0f;
                    }
                    else
                    {
                        _22354 = float((_4966[_19032] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _22373 = min(_19035, _22354);
                    _22370 = max(_19033, _22354);
                }
                else
                {
                    _22373 = _19035;
                    _22370 = _19033;
                }
            }
            float _5451 = float(_19033 >= 0.0f);
            float3 _18598 = 0.0f.xxx;
            _18598.y = _5451;
            float2 _19053;
            bool _19195;
            int2 _19276;
            float3 _21526;
            if ((_19033 - _19035) > 0.0199999995529651641845703125f)
            {
                float _19041;
                int2 _19042;
                float2 _19043;
                int2 _19045;
                float2 _19051;
                _19051 = _7874;
                _19045 = _5379;
                _19043 = _7874;
                _19042 = _5379;
                _19041 = -1.0f;
                float _22378;
                int2 _22382;
                float2 _22393;
                int2 _22404;
                float2 _22437;
                float _22754;
                int _19040 = 0;
                float _22335 = 1000000000.0f;
                for (; _19040 < 9; _22335 = _22754, _19051 = _22437, _19045 = _22404, _19043 = _22393, _19042 = _22382, _19041 = _22378, _19040++)
                {
                    if (_4966[_19040] == 0u)
                    {
                        _22754 = _22335;
                        _22437 = _19051;
                        _22404 = _19045;
                        _22393 = _19043;
                        _22382 = _19042;
                        _22378 = _19041;
                        continue;
                    }
                    int2 _5486 = clamp(_5379 + int2((_19040 % 3) - 1, (_19040 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _7984 = _4966[_19040] & 2147483647u;
                    uint _8016 = uint(max((int((_7984 >> 16u) & 15u) - 6), 0));
                    float2 _5492 = (float2(float((1 - (2 * int((_7984 >> 15u) & 1u))) * int(((_7984 >> uint(7)) & 127u) << _8016)), float((1 - (2 * int((_7984 >> 14u) & 1u))) * int((_7984 & 127u) << _8016))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _22321;
                    if (_4966[_19040] == 0u)
                    {
                        _22321 = -1.0f;
                    }
                    else
                    {
                        _22321 = float((_4966[_19040] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5497 = _22321 - 0.100000001490116119384765625f;
                    float2 _22322;
                    if (_7896)
                    {
                        float2 _8093 = clamp((((_19031 + (_5492 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8096 = tan(_8093.x);
                        _22322 = (float2(_8096 / cbFI_DeviceToViewDepth.z, (tan(_8093.y) * sqrt(1.0f + (_8096 * _8096))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _22322 = _19031 + (_5492 * cbFI_Timestep);
                    }
                    float _5504 = cbFI_Timestep - 1.0f;
                    float2 _22323;
                    if (_7896)
                    {
                        float2 _8164 = clamp((((_19031 + (_5492 * _5504)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8167 = tan(_8164.x);
                        _22323 = (float2(_8167 / cbFI_DeviceToViewDepth.z, (tan(_8164.y) * sqrt(1.0f + (_8167 * _8167))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _22323 = _19031 + (_5492 * _5504);
                    }
                    bool _8200 = all(bool2(_22322.x > 0.0f.xx.x, _22322.y > 0.0f.xx.y));
                    bool _8206;
                    if (_8200)
                    {
                        _8206 = all(bool2(_22322.x < 1.0f.xx.x, _22322.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8206 = _8200;
                    }
                    float _22326;
                    if (_8206)
                    {
                        uint _8213_dummy_parameter;
                        _22326 = max((_5497 - (log(((r_depth_tm1.Load(int3(int2(floor(_22322 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8213_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _22326 = 0.0f;
                    }
                    bool _8243 = all(bool2(_22323.x > 0.0f.xx.x, _22323.y > 0.0f.xx.y));
                    bool _8249;
                    if (_8243)
                    {
                        _8249 = all(bool2(_22323.x < 1.0f.xx.x, _22323.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8249 = _8243;
                    }
                    float _22327;
                    if (_8249)
                    {
                        uint _8256_dummy_parameter;
                        _22327 = _22326 + max((_5497 - (log(((r_depth_tp1.Load(int3(int2(floor(_22323 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8256_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _22327 = _22326;
                    }
                    float _22379;
                    int2 _22383;
                    float2 _22394;
                    int2 _22405;
                    float2 _22438;
                    float _22755;
                    if (_22327 == 0.0f)
                    {
                        bool _5539 = _5497 > _19041;
                        bool2 _22763 = _5539.xx;
                        _22755 = _22335;
                        _22438 = float2(_22763.x ? _5492.x : _19051.x, _22763.y ? _5492.y : _19051.y);
                        _22405 = int2(_22763.x ? _5486.x : _19045.x, _22763.y ? _5486.y : _19045.y);
                        _22394 = _19043;
                        _22383 = _19042;
                        _22379 = _5539 ? _5497 : _19041;
                    }
                    else
                    {
                        bool _5548 = _22327 < _22335;
                        bool2 _22759 = _5548.xx;
                        _22755 = _5548 ? _22327 : _22335;
                        _22438 = _19051;
                        _22405 = _19045;
                        _22394 = float2(_22759.x ? _5492.x : _19043.x, _22759.y ? _5492.y : _19043.y);
                        _22383 = int2(_22759.x ? _5486.x : _19042.x, _22759.y ? _5486.y : _19042.y);
                        _22379 = _19041;
                    }
                    _22754 = _22755;
                    _22437 = _22438;
                    _22404 = _22405;
                    _22393 = _22394;
                    _22382 = _22383;
                    _22378 = _22379;
                }
                bool _5560 = _19041 < 0.0f;
                bool2 _22769 = _5560.xx;
                int2 _22772 = int2(_22769.x ? _19042.x : _19045.x, _22769.y ? _19042.y : _19045.y);
                _21526 = float3(1.0f, _5451, float(any(bool2(_22772.x != _5379.x, _22772.y != _5379.y))));
                _19276 = _22772;
                _19195 = _5560 ? false : true;
                _19053 = float2(_22769.x ? _19043.x : _19051.x, _22769.y ? _19043.y : _19051.y);
            }
            else
            {
                _21526 = _18598;
                _19276 = _5379;
                _19195 = false;
                _19053 = _7874;
            }
            _21525 = _21526;
            _19275 = _19276;
            _19194 = _19195;
            _19052 = _19053;
        }
        else
        {
            _21525 = 0.0f.xxx;
            _19275 = _5379;
            _19194 = false;
            _19052 = _7874;
        }
        float2 _19054;
        if (_7896)
        {
            float2 _8321 = clamp((((_19031 + (_19052 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8324 = tan(_8321.x);
            _19054 = (float2(_8324 / cbFI_DeviceToViewDepth.z, (tan(_8321.y) * sqrt(1.0f + (_8324 * _8324))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19054 = _19031 + (_19052 * cbFI_Timestep);
        }
        float _5583 = cbFI_Timestep - 1.0f;
        float2 _19056;
        if (_7896)
        {
            float2 _8392 = clamp((((_19031 + (_19052 * _5583)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8395 = tan(_8392.x);
            _19056 = (float2(_8395 / cbFI_DeviceToViewDepth.z, (tan(_8392.y) * sqrt(1.0f + (_8395 * _8395))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19056 = _19031 + (_19052 * _5583);
        }
        float _5588 = -cbFI_Timestep;
        float2 _19057;
        if (_7896)
        {
            float2 _8463 = clamp((((_19031 + (_7868 * _5588)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8466 = tan(_8463.x);
            _19057 = (float2(_8466 / cbFI_DeviceToViewDepth.z, (tan(_8463.y) * sqrt(1.0f + (_8466 * _8466))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19057 = _19031 + (_7868 * _5588);
        }
        float _5593 = 1.0f - cbFI_Timestep;
        float2 _19058;
        if (_7896)
        {
            float2 _8534 = clamp((((_19031 + (_7868 * _5593)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8537 = tan(_8534.x);
            _19058 = (float2(_8537 / cbFI_DeviceToViewDepth.z, (tan(_8534.y) * sqrt(1.0f + (_8537 * _8537))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19058 = _19031 + (_7868 * _5593);
        }
        float4 _8572 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19054, 0.0f);
        float3 _8573 = _8572.xyz;
        float4 _8580 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19056, 0.0f);
        float3 _8581 = _8580.xyz;
        float4 _8588 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19057, 0.0f);
        float3 _8589 = _8588.xyz;
        float4 _8596 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19058, 0.0f);
        float3 _8597 = _8596.xyz;
        float4 _8611 = exp(_7862 - max(max(max(_7862.x, _7862.y), _7862.z), _7862.w).xxxx);
        float4 _8618 = _8611 / (dot(_8611, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5609 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19265;
        float _20573;
        if (_5609)
        {
            float2 _5615 = 0.5f.xx / _5370;
            float _5618 = _5615.x;
            float _5619 = -_5618;
            float _5621 = _5615.y;
            float _5622 = -_5621;
            float2 _5624 = _5368 + float2(_5619, _5622);
            float2 _5626 = float2(cbFI_DisplaySize);
            bool _19075;
            do
            {
                bool _8698 = all(bool2(_5624.x > 0.0f.xx.x, _5624.y > 0.0f.xx.y));
                bool _8704;
                if (_8698)
                {
                    _8704 = all(bool2(_5624.x < 1.0f.xx.x, _5624.y < 1.0f.xx.y));
                }
                else
                {
                    _8704 = _8698;
                }
                if (!_8704)
                {
                    _19075 = false;
                    break;
                }
                uint _8711_dummy_parameter;
                float4x4 _19073;
                do
                {
                    float4x4 _8725;
                    bool _19072;
                    do
                    {
                        _8725 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19072 = false;
                            break;
                        }
                        uint _8759 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8759 + 32u) * 4 + 0) != 1u)
                        {
                            _19072 = false;
                            break;
                        }
                        uint _19069;
                        _19069 = 0u;
                        for (; _19069 < 4u; _19069++)
                        {
                            for (uint _19070 = 0u; _19070 < 4u; )
                            {
                                _8725[_19069][_19070] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8759 + (_19069 * 4u)) + _19070) * 4 + 0));
                                _19070++;
                                continue;
                            }
                        }
                        _19072 = true;
                        break;
                    } while(false);
                    if (_19072)
                    {
                        _19073 = _8725;
                        break;
                    }
                    _19073 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19074;
                do
                {
                    float _8836 = _5624.x;
                    float _8839 = 1.0f - _5624.y;
                    float4 _8850 = mul(float4((float2(_8836, _8839) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5624 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8711_dummy_parameter))))), 0)).x, 1.0f), _19073);
                    float _8852 = _8850.w;
                    if (!(_8852 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19074 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8865 = ((_8850.xy / _8852.xx) + 1.0f.xx) * 0.5f;
                    _19074 = float2(_8865.x - _8836, _8839 - _8865.y);
                    break;
                } while(false);
                float2 _8662 = abs(_19074);
                if (any(bool2(_8662.x > 100000.0f.xx.x, _8662.y > 100000.0f.xx.y)))
                {
                    _19075 = false;
                    break;
                }
                float _8670 = length(_19074 * _5626);
                uint _8885_dummy_parameter;
                bool _8684 = _8670 > ((8.0f * _5626.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8691;
                if (_8684)
                {
                    _8691 = length((r_motion_tp1.Load(int3(int2(floor(_5624 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8885_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5626) < (0.20000000298023223876953125f * _8670);
                }
                else
                {
                    _8691 = _8684;
                }
                _19075 = _8691;
                break;
            } while(false);
            float2 _5636 = _5368 + float2(_5618, _5622);
            bool _19082;
            do
            {
                bool _8971 = all(bool2(_5636.x > 0.0f.xx.x, _5636.y > 0.0f.xx.y));
                bool _8977;
                if (_8971)
                {
                    _8977 = all(bool2(_5636.x < 1.0f.xx.x, _5636.y < 1.0f.xx.y));
                }
                else
                {
                    _8977 = _8971;
                }
                if (!_8977)
                {
                    _19082 = false;
                    break;
                }
                uint _8984_dummy_parameter;
                float4x4 _19080;
                do
                {
                    float4x4 _8998;
                    bool _19079;
                    do
                    {
                        _8998 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19079 = false;
                            break;
                        }
                        uint _9032 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9032 + 32u) * 4 + 0) != 1u)
                        {
                            _19079 = false;
                            break;
                        }
                        uint _19076;
                        _19076 = 0u;
                        for (; _19076 < 4u; _19076++)
                        {
                            for (uint _19077 = 0u; _19077 < 4u; )
                            {
                                _8998[_19076][_19077] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9032 + (_19076 * 4u)) + _19077) * 4 + 0));
                                _19077++;
                                continue;
                            }
                        }
                        _19079 = true;
                        break;
                    } while(false);
                    if (_19079)
                    {
                        _19080 = _8998;
                        break;
                    }
                    _19080 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19081;
                do
                {
                    float _9109 = _5636.x;
                    float _9112 = 1.0f - _5636.y;
                    float4 _9123 = mul(float4((float2(_9109, _9112) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5636 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8984_dummy_parameter))))), 0)).x, 1.0f), _19080);
                    float _9125 = _9123.w;
                    if (!(_9125 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19081 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9138 = ((_9123.xy / _9125.xx) + 1.0f.xx) * 0.5f;
                    _19081 = float2(_9138.x - _9109, _9112 - _9138.y);
                    break;
                } while(false);
                float2 _8935 = abs(_19081);
                if (any(bool2(_8935.x > 100000.0f.xx.x, _8935.y > 100000.0f.xx.y)))
                {
                    _19082 = false;
                    break;
                }
                float _8943 = length(_19081 * _5626);
                uint _9158_dummy_parameter;
                bool _8957 = _8943 > ((8.0f * _5626.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8964;
                if (_8957)
                {
                    _8964 = length((r_motion_tp1.Load(int3(int2(floor(_5636 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9158_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5626) < (0.20000000298023223876953125f * _8943);
                }
                else
                {
                    _8964 = _8957;
                }
                _19082 = _8964;
                break;
            } while(false);
            float2 _5649 = _5368 + float2(_5619, _5621);
            bool _19089;
            do
            {
                bool _9244 = all(bool2(_5649.x > 0.0f.xx.x, _5649.y > 0.0f.xx.y));
                bool _9250;
                if (_9244)
                {
                    _9250 = all(bool2(_5649.x < 1.0f.xx.x, _5649.y < 1.0f.xx.y));
                }
                else
                {
                    _9250 = _9244;
                }
                if (!_9250)
                {
                    _19089 = false;
                    break;
                }
                uint _9257_dummy_parameter;
                float4x4 _19087;
                do
                {
                    float4x4 _9271;
                    bool _19086;
                    do
                    {
                        _9271 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19086 = false;
                            break;
                        }
                        uint _9305 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9305 + 32u) * 4 + 0) != 1u)
                        {
                            _19086 = false;
                            break;
                        }
                        uint _19083;
                        _19083 = 0u;
                        for (; _19083 < 4u; _19083++)
                        {
                            for (uint _19084 = 0u; _19084 < 4u; )
                            {
                                _9271[_19083][_19084] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9305 + (_19083 * 4u)) + _19084) * 4 + 0));
                                _19084++;
                                continue;
                            }
                        }
                        _19086 = true;
                        break;
                    } while(false);
                    if (_19086)
                    {
                        _19087 = _9271;
                        break;
                    }
                    _19087 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19088;
                do
                {
                    float _9382 = _5649.x;
                    float _9385 = 1.0f - _5649.y;
                    float4 _9396 = mul(float4((float2(_9382, _9385) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5649 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9257_dummy_parameter))))), 0)).x, 1.0f), _19087);
                    float _9398 = _9396.w;
                    if (!(_9398 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19088 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9411 = ((_9396.xy / _9398.xx) + 1.0f.xx) * 0.5f;
                    _19088 = float2(_9411.x - _9382, _9385 - _9411.y);
                    break;
                } while(false);
                float2 _9208 = abs(_19088);
                if (any(bool2(_9208.x > 100000.0f.xx.x, _9208.y > 100000.0f.xx.y)))
                {
                    _19089 = false;
                    break;
                }
                float _9216 = length(_19088 * _5626);
                uint _9431_dummy_parameter;
                bool _9230 = _9216 > ((8.0f * _5626.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9237;
                if (_9230)
                {
                    _9237 = length((r_motion_tp1.Load(int3(int2(floor(_5649 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9431_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5626) < (0.20000000298023223876953125f * _9216);
                }
                else
                {
                    _9237 = _9230;
                }
                _19089 = _9237;
                break;
            } while(false);
            float2 _5661 = _5368 + _5615;
            bool _19096;
            do
            {
                bool _9517 = all(bool2(_5661.x > 0.0f.xx.x, _5661.y > 0.0f.xx.y));
                bool _9523;
                if (_9517)
                {
                    _9523 = all(bool2(_5661.x < 1.0f.xx.x, _5661.y < 1.0f.xx.y));
                }
                else
                {
                    _9523 = _9517;
                }
                if (!_9523)
                {
                    _19096 = false;
                    break;
                }
                uint _9530_dummy_parameter;
                float4x4 _19094;
                do
                {
                    float4x4 _9544;
                    bool _19093;
                    do
                    {
                        _9544 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19093 = false;
                            break;
                        }
                        uint _9578 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9578 + 32u) * 4 + 0) != 1u)
                        {
                            _19093 = false;
                            break;
                        }
                        uint _19090;
                        _19090 = 0u;
                        for (; _19090 < 4u; _19090++)
                        {
                            for (uint _19091 = 0u; _19091 < 4u; )
                            {
                                _9544[_19090][_19091] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9578 + (_19090 * 4u)) + _19091) * 4 + 0));
                                _19091++;
                                continue;
                            }
                        }
                        _19093 = true;
                        break;
                    } while(false);
                    if (_19093)
                    {
                        _19094 = _9544;
                        break;
                    }
                    _19094 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19095;
                do
                {
                    float _9655 = _5661.x;
                    float _9658 = 1.0f - _5661.y;
                    float4 _9669 = mul(float4((float2(_9655, _9658) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5661 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9530_dummy_parameter))))), 0)).x, 1.0f), _19094);
                    float _9671 = _9669.w;
                    if (!(_9671 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19095 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9684 = ((_9669.xy / _9671.xx) + 1.0f.xx) * 0.5f;
                    _19095 = float2(_9684.x - _9655, _9658 - _9684.y);
                    break;
                } while(false);
                float2 _9481 = abs(_19095);
                if (any(bool2(_9481.x > 100000.0f.xx.x, _9481.y > 100000.0f.xx.y)))
                {
                    _19096 = false;
                    break;
                }
                float _9489 = length(_19095 * _5626);
                uint _9704_dummy_parameter;
                bool _9503 = _9489 > ((8.0f * _5626.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9510;
                if (_9503)
                {
                    _9510 = length((r_motion_tp1.Load(int3(int2(floor(_5661 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9704_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5626) < (0.20000000298023223876953125f * _9489);
                }
                else
                {
                    _9510 = _9503;
                }
                _19096 = _9510;
                break;
            } while(false);
            float _5667 = 0.25f * (((float(_19075) + float(_19082)) + float(_19089)) + float(_19096));
            float4 _19266;
            if (_5667 < 1.0f)
            {
                bool _19103;
                do
                {
                    bool _9790 = all(bool2(_19054.x > 0.0f.xx.x, _19054.y > 0.0f.xx.y));
                    bool _9796;
                    if (_9790)
                    {
                        _9796 = all(bool2(_19054.x < 1.0f.xx.x, _19054.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9796 = _9790;
                    }
                    if (!_9796)
                    {
                        _19103 = false;
                        break;
                    }
                    uint _9803_dummy_parameter;
                    float4x4 _19101;
                    do
                    {
                        float4x4 _9817;
                        bool _19100;
                        do
                        {
                            _9817 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19100 = false;
                                break;
                            }
                            uint _9851 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9851 + 32u) * 4 + 0) != 1u)
                            {
                                _19100 = false;
                                break;
                            }
                            uint _19097;
                            _19097 = 0u;
                            for (; _19097 < 4u; _19097++)
                            {
                                for (uint _19098 = 0u; _19098 < 4u; )
                                {
                                    _9817[_19097][_19098] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9851 + (_19097 * 4u)) + _19098) * 4 + 0));
                                    _19098++;
                                    continue;
                                }
                            }
                            _19100 = true;
                            break;
                        } while(false);
                        if (_19100)
                        {
                            _19101 = _9817;
                            break;
                        }
                        _19101 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19102;
                    do
                    {
                        float _9931 = 1.0f - _19054.y;
                        float4 _9942 = mul(float4((float2(_19054.x, _9931) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19054 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9803_dummy_parameter))))), 0)).x, 1.0f), _19101);
                        float _9944 = _9942.w;
                        if (!(_9944 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19102 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9957 = ((_9942.xy / _9944.xx) + 1.0f.xx) * 0.5f;
                        _19102 = float2(_9957.x - _19054.x, _9931 - _9957.y);
                        break;
                    } while(false);
                    float2 _9754 = abs(_19102);
                    if (any(bool2(_9754.x > 100000.0f.xx.x, _9754.y > 100000.0f.xx.y)))
                    {
                        _19103 = false;
                        break;
                    }
                    float _9762 = length(_19102 * _5626);
                    uint _9977_dummy_parameter;
                    bool _9776 = _9762 > ((8.0f * _5626.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9783;
                    if (_9776)
                    {
                        _9783 = length((r_motion_tp1.Load(int3(int2(floor(_19054 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9977_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5626) < (0.20000000298023223876953125f * _9762);
                    }
                    else
                    {
                        _9783 = _9776;
                    }
                    _19103 = _9783;
                    break;
                } while(false);
                bool _19110;
                do
                {
                    bool _10063 = all(bool2(_19056.x > 0.0f.xx.x, _19056.y > 0.0f.xx.y));
                    bool _10069;
                    if (_10063)
                    {
                        _10069 = all(bool2(_19056.x < 1.0f.xx.x, _19056.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10069 = _10063;
                    }
                    if (!_10069)
                    {
                        _19110 = false;
                        break;
                    }
                    uint _10076_dummy_parameter;
                    float4x4 _19108;
                    do
                    {
                        float4x4 _10090;
                        bool _19107;
                        do
                        {
                            _10090 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19107 = false;
                                break;
                            }
                            uint _10124 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10124 + 32u) * 4 + 0) != 1u)
                            {
                                _19107 = false;
                                break;
                            }
                            uint _19104;
                            _19104 = 0u;
                            for (; _19104 < 4u; _19104++)
                            {
                                for (uint _19105 = 0u; _19105 < 4u; )
                                {
                                    _10090[_19104][_19105] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10124 + (_19104 * 4u)) + _19105) * 4 + 0));
                                    _19105++;
                                    continue;
                                }
                            }
                            _19107 = true;
                            break;
                        } while(false);
                        if (_19107)
                        {
                            _19108 = _10090;
                            break;
                        }
                        _19108 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19109;
                    do
                    {
                        float _10204 = 1.0f - _19056.y;
                        float4 _10215 = mul(float4((float2(_19056.x, _10204) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19056 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10076_dummy_parameter))))), 0)).x, 1.0f), _19108);
                        float _10217 = _10215.w;
                        if (!(_10217 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19109 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10230 = ((_10215.xy / _10217.xx) + 1.0f.xx) * 0.5f;
                        _19109 = float2(_10230.x - _19056.x, _10204 - _10230.y);
                        break;
                    } while(false);
                    float2 _10027 = abs(_19109);
                    if (any(bool2(_10027.x > 100000.0f.xx.x, _10027.y > 100000.0f.xx.y)))
                    {
                        _19110 = false;
                        break;
                    }
                    float _10035 = length(_19109 * _5626);
                    uint _10250_dummy_parameter;
                    bool _10049 = _10035 > ((8.0f * _5626.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10056;
                    if (_10049)
                    {
                        _10056 = length((r_motion_tp1.Load(int3(int2(floor(_19056 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10250_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5626) < (0.20000000298023223876953125f * _10035);
                    }
                    else
                    {
                        _10056 = _10049;
                    }
                    _19110 = _10056;
                    break;
                } while(false);
                bool _19117;
                do
                {
                    bool _10336 = all(bool2(_19057.x > 0.0f.xx.x, _19057.y > 0.0f.xx.y));
                    bool _10342;
                    if (_10336)
                    {
                        _10342 = all(bool2(_19057.x < 1.0f.xx.x, _19057.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10342 = _10336;
                    }
                    if (!_10342)
                    {
                        _19117 = false;
                        break;
                    }
                    uint _10349_dummy_parameter;
                    float4x4 _19115;
                    do
                    {
                        float4x4 _10363;
                        bool _19114;
                        do
                        {
                            _10363 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19114 = false;
                                break;
                            }
                            uint _10397 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10397 + 32u) * 4 + 0) != 1u)
                            {
                                _19114 = false;
                                break;
                            }
                            uint _19111;
                            _19111 = 0u;
                            for (; _19111 < 4u; _19111++)
                            {
                                for (uint _19112 = 0u; _19112 < 4u; )
                                {
                                    _10363[_19111][_19112] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10397 + (_19111 * 4u)) + _19112) * 4 + 0));
                                    _19112++;
                                    continue;
                                }
                            }
                            _19114 = true;
                            break;
                        } while(false);
                        if (_19114)
                        {
                            _19115 = _10363;
                            break;
                        }
                        _19115 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19116;
                    do
                    {
                        float _10477 = 1.0f - _19057.y;
                        float4 _10488 = mul(float4((float2(_19057.x, _10477) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19057 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10349_dummy_parameter))))), 0)).x, 1.0f), _19115);
                        float _10490 = _10488.w;
                        if (!(_10490 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19116 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10503 = ((_10488.xy / _10490.xx) + 1.0f.xx) * 0.5f;
                        _19116 = float2(_10503.x - _19057.x, _10477 - _10503.y);
                        break;
                    } while(false);
                    float2 _10300 = abs(_19116);
                    if (any(bool2(_10300.x > 100000.0f.xx.x, _10300.y > 100000.0f.xx.y)))
                    {
                        _19117 = false;
                        break;
                    }
                    float _10308 = length(_19116 * _5626);
                    uint _10523_dummy_parameter;
                    bool _10322 = _10308 > ((8.0f * _5626.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10329;
                    if (_10322)
                    {
                        _10329 = length((r_motion_tp1.Load(int3(int2(floor(_19057 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10523_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5626) < (0.20000000298023223876953125f * _10308);
                    }
                    else
                    {
                        _10329 = _10322;
                    }
                    _19117 = _10329;
                    break;
                } while(false);
                bool _19124;
                do
                {
                    bool _10609 = all(bool2(_19058.x > 0.0f.xx.x, _19058.y > 0.0f.xx.y));
                    bool _10615;
                    if (_10609)
                    {
                        _10615 = all(bool2(_19058.x < 1.0f.xx.x, _19058.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10615 = _10609;
                    }
                    if (!_10615)
                    {
                        _19124 = false;
                        break;
                    }
                    uint _10622_dummy_parameter;
                    float4x4 _19122;
                    do
                    {
                        float4x4 _10636;
                        bool _19121;
                        do
                        {
                            _10636 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19121 = false;
                                break;
                            }
                            uint _10670 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10670 + 32u) * 4 + 0) != 1u)
                            {
                                _19121 = false;
                                break;
                            }
                            uint _19118;
                            _19118 = 0u;
                            for (; _19118 < 4u; _19118++)
                            {
                                for (uint _19119 = 0u; _19119 < 4u; )
                                {
                                    _10636[_19118][_19119] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10670 + (_19118 * 4u)) + _19119) * 4 + 0));
                                    _19119++;
                                    continue;
                                }
                            }
                            _19121 = true;
                            break;
                        } while(false);
                        if (_19121)
                        {
                            _19122 = _10636;
                            break;
                        }
                        _19122 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19123;
                    do
                    {
                        float _10750 = 1.0f - _19058.y;
                        float4 _10761 = mul(float4((float2(_19058.x, _10750) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19058 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10622_dummy_parameter))))), 0)).x, 1.0f), _19122);
                        float _10763 = _10761.w;
                        if (!(_10763 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19123 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10776 = ((_10761.xy / _10763.xx) + 1.0f.xx) * 0.5f;
                        _19123 = float2(_10776.x - _19058.x, _10750 - _10776.y);
                        break;
                    } while(false);
                    float2 _10573 = abs(_19123);
                    if (any(bool2(_10573.x > 100000.0f.xx.x, _10573.y > 100000.0f.xx.y)))
                    {
                        _19124 = false;
                        break;
                    }
                    float _10581 = length(_19123 * _5626);
                    uint _10796_dummy_parameter;
                    bool _10595 = _10581 > ((8.0f * _5626.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10602;
                    if (_10595)
                    {
                        _10602 = length((r_motion_tp1.Load(int3(int2(floor(_19058 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10796_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5626) < (0.20000000298023223876953125f * _10581);
                    }
                    else
                    {
                        _10602 = _10595;
                    }
                    _19124 = _10602;
                    break;
                } while(false);
                float4 _5694 = _8618 * float4(_19103 ? 0.0f : 1.0f, _19110 ? 0.0f : 1.0f, _19117 ? 0.0f : 1.0f, _19124 ? 0.0f : 1.0f);
                float _5696 = dot(_5694, 1.0f.xxxx);
                float4 _19267;
                if (_5696 > 0.001000000047497451305389404296875f)
                {
                    _19267 = _5694 / _5696.xxxx;
                }
                else
                {
                    _19267 = _8618;
                }
                _19266 = _19267;
            }
            else
            {
                _19266 = _8618;
            }
            _20573 = _5667;
            _19265 = _19266;
        }
        else
        {
            _20573 = 0.0f;
            _19265 = _8618;
        }
        bool _5713 = _5405 && (!_19194);
        bool _5722;
        if (_5713)
        {
            _5722 = (_19265.z + _19265.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5722 = _5713;
        }
        bool _5733;
        if (_5722)
        {
            _5733 = length((_19057 - _19054) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5733 = _5722;
        }
        bool _19354;
        if (_5733)
        {
            uint4 _10825 = r_warped_motion_qdata_tp1.Load(int3(_19275, 0));
            uint _10826 = _10825.x;
            bool _19357;
            if (_10826 != 0u)
            {
                float _19343;
                if (_10826 == 0u)
                {
                    _19343 = -1.0f;
                }
                else
                {
                    _19343 = float((_10826 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5743 = _19343 - 0.12000000476837158203125f;
                bool _10845 = all(bool2(_19057.x > 0.0f.xx.x, _19057.y > 0.0f.xx.y));
                bool _10851;
                if (_10845)
                {
                    _10851 = all(bool2(_19057.x < 1.0f.xx.x, _19057.y < 1.0f.xx.y));
                }
                else
                {
                    _10851 = _10845;
                }
                bool _5753;
                if (_10851)
                {
                    uint _10858_dummy_parameter;
                    _5753 = (log(((r_depth_tm1.Load(int3(int2(floor(_19057 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10858_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5743;
                }
                else
                {
                    _5753 = _10851;
                }
                bool _5767;
                if (!_5753)
                {
                    bool _10888 = all(bool2(_19058.x > 0.0f.xx.x, _19058.y > 0.0f.xx.y));
                    bool _10894;
                    if (_10888)
                    {
                        _10894 = all(bool2(_19058.x < 1.0f.xx.x, _19058.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10894 = _10888;
                    }
                    bool _5765;
                    if (_10894)
                    {
                        uint _10901_dummy_parameter;
                        _5765 = (log(((r_depth_tp1.Load(int3(int2(floor(_19058 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10901_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5743;
                    }
                    else
                    {
                        _5765 = _10894;
                    }
                    _5767 = _5765;
                }
                else
                {
                    _5767 = _5753;
                }
                _19357 = _5767;
            }
            else
            {
                _19357 = false;
            }
            _19354 = _19357;
        }
        else
        {
            _19354 = false;
        }
        bool _5772 = _19194 || _19354;
        bool _5777;
        if (_5772)
        {
            bool _10931 = all(bool2(_19054.x > 0.0f.xx.x, _19054.y > 0.0f.xx.y));
            bool _10937;
            if (_10931)
            {
                _10937 = all(bool2(_19054.x < 1.0f.xx.x, _19054.y < 1.0f.xx.y));
            }
            else
            {
                _10937 = _10931;
            }
            _5777 = _10937;
        }
        else
        {
            _5777 = _5772;
        }
        bool _5782;
        if (_5777)
        {
            bool _10942 = all(bool2(_19056.x > 0.0f.xx.x, _19056.y > 0.0f.xx.y));
            bool _10948;
            if (_10942)
            {
                _10948 = all(bool2(_19056.x < 1.0f.xx.x, _19056.y < 1.0f.xx.y));
            }
            else
            {
                _10948 = _10942;
            }
            _5782 = _10948;
        }
        else
        {
            _5782 = _5777;
        }
        float4 _19477;
        if (_5782)
        {
            float _5788 = _19265.x + _19265.y;
            float _5793 = _19265.z + _19265.w;
            float _19372;
            if (_5788 > 0.001000000047497451305389404296875f)
            {
                _19372 = _19265.x / _5788;
            }
            else
            {
                _19372 = _5593;
            }
            _19477 = float4(_19265.x + (_5793 * _19372), _19265.y + (_5793 * (1.0f - _19372)), 0.0f, 0.0f);
        }
        else
        {
            _19477 = _19265;
        }
        bool _10976 = (cbFI_pad0 & 1024u) != 0u;
        bool _10952 = !_10976;
        bool _10953 = !_10952;
        bool _10970;
        if (_10953)
        {
            _10970 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19275.y * cbFI_MvDepthLaneSize.x) + _19275.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _10970 = _10952;
        }
        bool _11002;
        if (_10953)
        {
            _11002 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5384.y * cbFI_FlowLaneSize.x) + _5384.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11002 = _10952;
        }
        float _5828 = float(_11002);
        bool _19498;
        float4 _19537;
        float3 _21267;
        if (_10976)
        {
            bool _5838;
            if (_10970)
            {
                _5838 = all(bool2(_19054.x > 0.0f.xx.x, _19054.y > 0.0f.xx.y));
            }
            else
            {
                _5838 = _10970;
            }
            bool _5844;
            if (_5838)
            {
                _5844 = all(bool2(_19054.x < 1.0f.xx.x, _19054.y < 1.0f.xx.y));
            }
            else
            {
                _5844 = _5838;
            }
            bool _5851;
            if (_10970)
            {
                _5851 = all(bool2(_19056.x > 0.0f.xx.x, _19056.y > 0.0f.xx.y));
            }
            else
            {
                _5851 = _10970;
            }
            bool _5857;
            if (_5851)
            {
                _5857 = all(bool2(_19056.x < 1.0f.xx.x, _19056.y < 1.0f.xx.y));
            }
            else
            {
                _5857 = _5851;
            }
            bool _5864;
            if (_11002)
            {
                _5864 = all(bool2(_19057.x > 0.0f.xx.x, _19057.y > 0.0f.xx.y));
            }
            else
            {
                _5864 = _11002;
            }
            bool _5870;
            if (_5864)
            {
                _5870 = all(bool2(_19057.x < 1.0f.xx.x, _19057.y < 1.0f.xx.y));
            }
            else
            {
                _5870 = _5864;
            }
            bool _5877;
            if (_11002)
            {
                _5877 = all(bool2(_19058.x > 0.0f.xx.x, _19058.y > 0.0f.xx.y));
            }
            else
            {
                _5877 = _11002;
            }
            bool _5883;
            if (_5877)
            {
                _5883 = all(bool2(_19058.x < 1.0f.xx.x, _19058.y < 1.0f.xx.y));
            }
            else
            {
                _5883 = _5877;
            }
            bool _5885 = !_10970;
            if (_5885)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11044;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11044);
                }
            }
            bool _5890 = !_11002;
            if (_5890)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11054;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11054);
                }
            }
            if (_10970 && _5890)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11064;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11064);
                }
            }
            if (_5885 && _11002)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11074;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11074);
                }
            }
            float _5909 = float(_5844);
            float _5911 = float(_5857);
            bool _5914 = _5870 && _5883;
            float _19406;
            if (_5914)
            {
                _19406 = 1.0f;
            }
            else
            {
                _19406 = (_5870 || _5883) ? 0.5f : 0.0f;
            }
            bool _19421;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5844)) && (!_5857))
            {
                bool _5944;
                if (_5914)
                {
                    float _19414;
                    do
                    {
                        bool _11158 = all(bool2(_19057.x > 0.0f.xx.x, _19057.y > 0.0f.xx.y));
                        bool _11164;
                        if (_11158)
                        {
                            _11164 = all(bool2(_19057.x < 1.0f.xx.x, _19057.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11164 = _11158;
                        }
                        bool _11095 = !_11164;
                        bool _11102;
                        if (!_11095)
                        {
                            bool _11169 = all(bool2(_19058.x > 0.0f.xx.x, _19058.y > 0.0f.xx.y));
                            bool _11175;
                            if (_11169)
                            {
                                _11175 = all(bool2(_19058.x < 1.0f.xx.x, _19058.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11175 = _11169;
                            }
                            _11102 = !_11175;
                        }
                        else
                        {
                            _11102 = _11095;
                        }
                        if (_11102)
                        {
                            _19414 = 0.0f;
                            break;
                        }
                        uint _11182_dummy_parameter;
                        uint _11198_dummy_parameter;
                        float4x4 _19413;
                        do
                        {
                            float4x4 _11212;
                            bool _19412;
                            do
                            {
                                _11212 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _19412 = false;
                                    break;
                                }
                                uint _11246 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11246 + 32u) * 4 + 0) != 1u)
                                {
                                    _19412 = false;
                                    break;
                                }
                                uint _19409;
                                _19409 = 0u;
                                for (; _19409 < 4u; _19409++)
                                {
                                    for (uint _19410 = 0u; _19410 < 4u; )
                                    {
                                        _11212[_19409][_19410] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11246 + 16u) + (_19409 * 4u)) + _19410) * 4 + 0));
                                        _19410++;
                                        continue;
                                    }
                                }
                                _19412 = true;
                                break;
                            } while(false);
                            if (_19412)
                            {
                                _19413 = _11212;
                                break;
                            }
                            _19413 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11123 = mul(float4((float2(_19057.x, 1.0f - _19057.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19057 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11182_dummy_parameter))))), 0)).x, 1.0f), _19413);
                        float _11125 = _11123.w;
                        if (abs(_11125) < 9.9999999747524270787835121154785e-07f)
                        {
                            _19414 = 0.0f;
                            break;
                        }
                        float _11136 = abs(cbFI_DeviceToViewDepth.y / ((_11123.z / _11125) - cbFI_DeviceToViewDepth.x));
                        float _11139 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19058 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11198_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _19414 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11136 - _11139) / max(max(_11136, _11139), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5944 = _19414 >= 0.5f;
                }
                else
                {
                    _5944 = _5914;
                }
                bool _5952;
                if (_5944)
                {
                    _5952 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5952 = _5944;
                }
                bool _19422;
                if (_5952)
                {
                    uint _11350_dummy_parameter;
                    float4x4 _19419;
                    do
                    {
                        float4x4 _11364;
                        bool _19418;
                        do
                        {
                            _11364 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19418 = false;
                                break;
                            }
                            uint _11398 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11398 + 32u) * 4 + 0) != 1u)
                            {
                                _19418 = false;
                                break;
                            }
                            uint _19415;
                            _19415 = 0u;
                            for (; _19415 < 4u; _19415++)
                            {
                                for (uint _19416 = 0u; _19416 < 4u; )
                                {
                                    _11364[_19415][_19416] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11398 + 16u) + (_19415 * 4u)) + _19416) * 4 + 0));
                                    _19416++;
                                    continue;
                                }
                            }
                            _19418 = true;
                            break;
                        } while(false);
                        if (_19418)
                        {
                            _19419 = _11364;
                            break;
                        }
                        _19419 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _19420;
                    do
                    {
                        float _11478 = 1.0f - _19057.y;
                        float4 _11489 = mul(float4((float2(_19057.x, _11478) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19057 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11350_dummy_parameter))))), 0)).x, 1.0f), _19419);
                        float _11491 = _11489.w;
                        if (!(_11491 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19420 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11504 = ((_11489.xy / _11491.xx) + 1.0f.xx) * 0.5f;
                        _19420 = float2(_11504.x - _19057.x, _11478 - _11504.y);
                        break;
                    } while(false);
                    float2 _5965 = float2(cbFI_DisplaySize);
                    _19422 = length(((_19057 + _19420) - _19058) * _5965) <= ((0.100000001490116119384765625f * length(_19420 * _5965)) + 8.0f);
                }
                else
                {
                    _19422 = _5944;
                }
                _19421 = _19422;
            }
            else
            {
                _19421 = true;
            }
            bool _5979 = !_19421;
            bool _22773 = _5979 ? false : _5883;
            bool _22774 = _5979 ? false : _5870;
            bool _19499;
            float4 _19538;
            if (!(((_5844 && _5857) && _22774) && _22773))
            {
                float4 _6001 = _19477 * float4(_5909, _5911, float(_22774), float(_22773));
                float _6003 = dot(_6001, 1.0f.xxxx);
                bool _6006 = !(_6003 > 0.0f);
                float4 _19539;
                if (!_6006)
                {
                    _19539 = _6001 / _6003.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11526;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11526);
                    }
                    _19539 = 0.0f.xxxx;
                }
                _19538 = _19539;
                _19499 = _6006;
            }
            else
            {
                _19538 = _19477;
                _19499 = false;
            }
            _21267 = float3(_5909, _5911, _19406);
            _19537 = _19538;
            _19498 = _19499;
        }
        else
        {
            _21267 = float3(float(_10970), _5828, 0.0f);
            _19537 = _19477;
            _19498 = false;
        }
        bool _6024 = !_19498;
        float4 _19630;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6024)
        {
            float _6031 = _19537.x + _19537.y;
            float4 _19631;
            if (_6031 > 0.001000000047497451305389404296875f)
            {
                _19631 = float4(_19537.x / _6031, _19537.y / _6031, 0.0f, 0.0f);
            }
            else
            {
                _19631 = float4(_5593, cbFI_Timestep, 0.0f, 0.0f);
            }
            _19630 = _19631;
        }
        else
        {
            _19630 = _19537;
        }
        float4 _19807;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6024) && _10970)
        {
            float _19604;
            do
            {
                uint4 _11666 = r_warped_motion_qdata_tp1.Load(int3(_19275, 0));
                uint _11667 = _11666.x;
                if (_11667 != 0u)
                {
                    float _19603;
                    if (_11667 == 0u)
                    {
                        _19603 = -1.0f;
                    }
                    else
                    {
                        _19603 = float((_11667 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19604 = _19603;
                    break;
                }
                int _19586;
                uint _19587;
                _19587 = _11667;
                _19586 = -1;
                uint _19602;
                for (; _19586 <= 1; _19587 = _19602, _19586++)
                {
                    _19602 = _19587;
                    for (int _19600 = -1; _19600 <= 1; )
                    {
                        _19602 = max(_19602, r_warped_motion_qdata_tp1.Load(int3(clamp(_19275 + int2(_19600, _19586), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _19600++;
                        continue;
                    }
                }
                if (_19587 != 0u)
                {
                    float _19599;
                    if (_19587 == 0u)
                    {
                        _19599 = -1.0f;
                    }
                    else
                    {
                        _19599 = float((_19587 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19604 = _19599;
                    break;
                }
                uint _19589;
                _19589 = 4294967295u;
                uint _22474;
                for (int _19588 = 0; _19588 < 8; _19589 = _22474, _19588++)
                {
                    int _19592 = 0;
                    for (;;)
                    {
                        if (_19592 < 5)
                        {
                            int2 _11617 = _19275 + (_1243[_19588] * _1252[_19592].xx);
                            bool _11620 = any(bool2(_11617.x < int2(0, 0).x, _11617.y < int2(0, 0).y));
                            bool _11628;
                            if (!_11620)
                            {
                                _11628 = any(bool2(_11617.x >= cbFI_MvDepthLaneSize.x, _11617.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11628 = _11620;
                            }
                            if (_11628)
                            {
                                _22474 = _19589;
                                break;
                            }
                            uint4 _11706 = r_warped_motion_qdata_tp1.Load(int3(_11617, 0));
                            uint _11707 = _11706.x;
                            if (_11707 != 0u)
                            {
                                _22474 = min(_19589, _11707);
                                break;
                            }
                            _19592++;
                            continue;
                        }
                        else
                        {
                            _22474 = _19589;
                            break;
                        }
                    }
                }
                float _19591;
                if (_19589 == 4294967295u)
                {
                    _19591 = -1.0f;
                }
                else
                {
                    float _19590;
                    if (_19589 == 0u)
                    {
                        _19590 = -1.0f;
                    }
                    else
                    {
                        _19590 = float((_19589 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19591 = _19590;
                }
                _19604 = _19591;
                break;
            } while(false);
            float _6067 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6070 = r_warped_motion_qdata_tp1.Load(int3(_19275, 0)).x == 0u;
            bool _6076;
            if (_6070)
            {
                bool _11732 = all(bool2(_19054.x > 0.0f.xx.x, _19054.y > 0.0f.xx.y));
                bool _11738;
                if (_11732)
                {
                    _11738 = all(bool2(_19054.x < 1.0f.xx.x, _19054.y < 1.0f.xx.y));
                }
                else
                {
                    _11738 = _11732;
                }
                _6076 = _11738;
            }
            else
            {
                _6076 = _6070;
            }
            bool _6081;
            if (_6076)
            {
                bool _11743 = all(bool2(_19056.x > 0.0f.xx.x, _19056.y > 0.0f.xx.y));
                bool _11749;
                if (_11743)
                {
                    _11749 = all(bool2(_19056.x < 1.0f.xx.x, _19056.y < 1.0f.xx.y));
                }
                else
                {
                    _11749 = _11743;
                }
                _6081 = _11749;
            }
            else
            {
                _6081 = _6076;
            }
            bool _19616;
            float4 _19625;
            if (_6081)
            {
                uint _11756_dummy_parameter;
                float _11780 = log(((r_depth_tm1.Load(int3(int2(floor(_19054 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11756_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _11788_dummy_parameter;
                float _11812 = log(((r_depth_tp1.Load(int3(int2(floor(_19056 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11788_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _6092 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6099;
                if (_6092)
                {
                    _6099 = _11812 > (_11780 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6099 = _6092;
                }
                bool _19621;
                float4 _19643;
                if (_6099)
                {
                    _19643 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _19621 = true;
                }
                else
                {
                    bool _6105 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6112;
                    if (_6105)
                    {
                        _6112 = _11780 > (_11812 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6112 = _6105;
                    }
                    bool4 _22775 = _6112.xxxx;
                    _19643 = float4(_22775.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _19630.x, _22775.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _19630.y, _22775.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _19630.z, _22775.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _19630.w);
                    _19621 = _6112 ? true : false;
                }
                _19625 = _19643;
                _19616 = _19621;
            }
            else
            {
                _19625 = _19630;
                _19616 = false;
            }
            float4 _19698;
            if (_19616)
            {
                _19698 = 1.0f.xxxx;
            }
            else
            {
                bool _6123 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6129;
                if (_6123)
                {
                    _6129 = _19625.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6129 = _6123;
                }
                bool _6134;
                if (_6129)
                {
                    bool _11818 = all(bool2(_19056.x > 0.0f.xx.x, _19056.y > 0.0f.xx.y));
                    bool _11824;
                    if (_11818)
                    {
                        _11824 = all(bool2(_19056.x < 1.0f.xx.x, _19056.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11824 = _11818;
                    }
                    _6134 = _11824;
                }
                else
                {
                    _6134 = _6129;
                }
                float4 _19699;
                if (_6134)
                {
                    float _19652;
                    if (_19604 >= 0.0f)
                    {
                        _19652 = _19604 - _6067;
                    }
                    else
                    {
                        float _19648;
                        _19648 = 2.0f;
                        float _11881;
                        for (int _19647 = 0; _19647 < 24; _19648 = _11881, _19647++)
                        {
                            float _11845 = float(_19647 & 7) * 0.785398185253143310546875f;
                            int _11847 = _19647 >> 3;
                            int _19649;
                            if (_11847 == 0)
                            {
                                _19649 = 16;
                            }
                            else
                            {
                                _19649 = (_11847 == 1) ? 48 : 96;
                            }
                            uint _11913_dummy_parameter;
                            _11881 = min(_19648, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19056 + ((cbFI_MvDepthLaneSizeRcp * float(_19649)) * float2(cos(_11845), sin(_11845))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11913_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _19652 = _19648;
                    }
                    uint _11945_dummy_parameter;
                    float4 _19700;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_19056 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11945_dummy_parameter))))), 0)).x) > ((exp((_19652 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _19700 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _19700 = 1.0f.xxxx;
                    }
                    _19699 = _19700;
                }
                else
                {
                    _19699 = 1.0f.xxxx;
                }
                _19698 = _19699;
            }
            bool _6162 = _19604 >= 0.0f;
            bool _6163 = (!_19616) && _6162;
            bool _6170;
            if (_6163)
            {
                _6170 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6170 = _6163;
            }
            bool _6176;
            if (_6170)
            {
                _6176 = _19625.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6176 = _6170;
            }
            bool _6181;
            if (_6176)
            {
                bool _11970 = all(bool2(_19054.x > 0.0f.xx.x, _19054.y > 0.0f.xx.y));
                bool _11976;
                if (_11970)
                {
                    _11976 = all(bool2(_19054.x < 1.0f.xx.x, _19054.y < 1.0f.xx.y));
                }
                else
                {
                    _11976 = _11970;
                }
                _6181 = _11976;
            }
            else
            {
                _6181 = _6176;
            }
            float4 _19723;
            if (_6181)
            {
                float _19692;
                if (_6162)
                {
                    _19692 = _19604 - _6067;
                }
                else
                {
                    float _19688;
                    _19688 = 2.0f;
                    float _12033;
                    for (int _19687 = 0; _19687 < 24; _19688 = _12033, _19687++)
                    {
                        float _11997 = float(_19687 & 7) * 0.785398185253143310546875f;
                        int _11999 = _19687 >> 3;
                        int _19689;
                        if (_11999 == 0)
                        {
                            _19689 = 16;
                        }
                        else
                        {
                            _19689 = (_11999 == 1) ? 48 : 96;
                        }
                        uint _12049_dummy_parameter;
                        _12033 = min(_19688, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19054 + ((cbFI_MvDepthLaneSizeRcp * float(_19689)) * float2(cos(_11997), sin(_11997))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12049_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _19692 = _19688;
                }
                uint _12097_dummy_parameter;
                float4 _19724;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_19054 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12097_dummy_parameter))))), 0)).x) > ((exp((_19692 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _18750 = _19698;
                    _18750.x = 0.0f;
                    _19724 = _18750;
                }
                else
                {
                    _19724 = _19698;
                }
                _19723 = _19724;
            }
            else
            {
                _19723 = _19698;
            }
            float4 _19736;
            if (_6163)
            {
                float _12124 = (exp(((_19604 - _6067) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6219 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6225;
                if (_6219)
                {
                    _6225 = _19625.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6225 = _6219;
                }
                bool _6230;
                if (_6225)
                {
                    bool _12129 = all(bool2(_19058.x > 0.0f.xx.x, _19058.y > 0.0f.xx.y));
                    bool _12135;
                    if (_12129)
                    {
                        _12135 = all(bool2(_19058.x < 1.0f.xx.x, _19058.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12135 = _12129;
                    }
                    _6230 = _12135;
                }
                else
                {
                    _6230 = _6225;
                }
                bool _6238;
                if (_6230)
                {
                    uint _12142_dummy_parameter;
                    _6238 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19058 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12142_dummy_parameter))))), 0)).x) > _12124;
                }
                else
                {
                    _6238 = _6230;
                }
                float4 _19734;
                if (_6238)
                {
                    float4 _18753 = _19723;
                    _18753.w = 0.0f;
                    _19734 = _18753;
                }
                else
                {
                    _19734 = _19723;
                }
                bool _6245 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6251;
                if (_6245)
                {
                    _6251 = _19625.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6251 = _6245;
                }
                bool _6256;
                if (_6251)
                {
                    bool _12160 = all(bool2(_19057.x > 0.0f.xx.x, _19057.y > 0.0f.xx.y));
                    bool _12166;
                    if (_12160)
                    {
                        _12166 = all(bool2(_19057.x < 1.0f.xx.x, _19057.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12166 = _12160;
                    }
                    _6256 = _12166;
                }
                else
                {
                    _6256 = _6251;
                }
                bool _6264;
                if (_6256)
                {
                    uint _12173_dummy_parameter;
                    _6264 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19057 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12173_dummy_parameter))))), 0)).x) > _12124;
                }
                else
                {
                    _6264 = _6256;
                }
                float4 _19737;
                if (_6264)
                {
                    float4 _18756 = _19734;
                    _18756.z = 0.0f;
                    _19737 = _18756;
                }
                else
                {
                    _19737 = _19734;
                }
                _19736 = _19737;
            }
            else
            {
                _19736 = _19723;
            }
            float4 _19808;
            if (any(bool4(_19736.x < 1.0f.xxxx.x, _19736.y < 1.0f.xxxx.y, _19736.z < 1.0f.xxxx.z, _19736.w < 1.0f.xxxx.w)))
            {
                float4 _6275 = _19625 * _19736;
                float _6277 = dot(_6275, 1.0f.xxxx);
                float4 _19809;
                if (_6277 > 0.0f)
                {
                    _19809 = _6275 / _6277.xxxx;
                }
                else
                {
                    bool _6288 = _19736.y == 0.0f;
                    bool _6294;
                    if (_6288)
                    {
                        _6294 = _19736.x > 0.0f;
                    }
                    else
                    {
                        _6294 = _6288;
                    }
                    bool _6299;
                    if (_6294)
                    {
                        bool _12191 = all(bool2(_19054.x > 0.0f.xx.x, _19054.y > 0.0f.xx.y));
                        bool _12197;
                        if (_12191)
                        {
                            _12197 = all(bool2(_19054.x < 1.0f.xx.x, _19054.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12197 = _12191;
                        }
                        _6299 = _12197;
                    }
                    else
                    {
                        _6299 = _6294;
                    }
                    float4 _19810;
                    if (_6299)
                    {
                        _19810 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6304 = _19736.x == 0.0f;
                        bool _6310;
                        if (_6304)
                        {
                            _6310 = _19736.y > 0.0f;
                        }
                        else
                        {
                            _6310 = _6304;
                        }
                        bool _6315;
                        if (_6310)
                        {
                            bool _12202 = all(bool2(_19056.x > 0.0f.xx.x, _19056.y > 0.0f.xx.y));
                            bool _12208;
                            if (_12202)
                            {
                                _12208 = all(bool2(_19056.x < 1.0f.xx.x, _19056.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12208 = _12202;
                            }
                            _6315 = _12208;
                        }
                        else
                        {
                            _6315 = _6310;
                        }
                        bool4 _22778 = _6315.xxxx;
                        _19810 = float4(_22778.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _19625.x, _22778.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _19625.y, _22778.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _19625.z, _22778.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _19625.w);
                    }
                    _19809 = _19810;
                }
                _19808 = _19809;
            }
            else
            {
                _19808 = _19625;
            }
            _19807 = _19808;
        }
        else
        {
            _19807 = _19630;
        }
        float4 _20537;
        bool _20843;
        float3 _21015;
        if (((cbFI_pad0 & 32768u) != 0u) && _6024)
        {
            bool _6332 = _19807.x > 0.00999999977648258209228515625f;
            bool _6335 = _19807.y > 0.00999999977648258209228515625f;
            bool _6344 = (_19807.z + _19807.w) > 0.0199999995529651641845703125f;
            bool _6350;
            if (_6344)
            {
                bool _12213 = all(bool2(_19057.x > 0.0f.xx.x, _19057.y > 0.0f.xx.y));
                bool _12219;
                if (_12213)
                {
                    _12219 = all(bool2(_19057.x < 1.0f.xx.x, _19057.y < 1.0f.xx.y));
                }
                else
                {
                    _12219 = _12213;
                }
                _6350 = _12219;
            }
            else
            {
                _6350 = _6344;
            }
            bool _6355;
            if (_6350)
            {
                bool _12224 = all(bool2(_19058.x > 0.0f.xx.x, _19058.y > 0.0f.xx.y));
                bool _12230;
                if (_12224)
                {
                    _12230 = all(bool2(_19058.x < 1.0f.xx.x, _19058.y < 1.0f.xx.y));
                }
                else
                {
                    _12230 = _12224;
                }
                _6355 = _12230;
            }
            else
            {
                _6355 = _6350;
            }
            bool _6362;
            if (_6355)
            {
                float _19823;
                do
                {
                    bool _12313 = all(bool2(_19057.x > 0.0f.xx.x, _19057.y > 0.0f.xx.y));
                    bool _12319;
                    if (_12313)
                    {
                        _12319 = all(bool2(_19057.x < 1.0f.xx.x, _19057.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12319 = _12313;
                    }
                    bool _12250 = !_12319;
                    bool _12257;
                    if (!_12250)
                    {
                        bool _12324 = all(bool2(_19058.x > 0.0f.xx.x, _19058.y > 0.0f.xx.y));
                        bool _12330;
                        if (_12324)
                        {
                            _12330 = all(bool2(_19058.x < 1.0f.xx.x, _19058.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12330 = _12324;
                        }
                        _12257 = !_12330;
                    }
                    else
                    {
                        _12257 = _12250;
                    }
                    if (_12257)
                    {
                        _19823 = 0.0f;
                        break;
                    }
                    uint _12337_dummy_parameter;
                    uint _12353_dummy_parameter;
                    float4x4 _19822;
                    do
                    {
                        float4x4 _12367;
                        bool _19821;
                        do
                        {
                            _12367 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19821 = false;
                                break;
                            }
                            uint _12401 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12401 + 32u) * 4 + 0) != 1u)
                            {
                                _19821 = false;
                                break;
                            }
                            uint _19818;
                            _19818 = 0u;
                            for (; _19818 < 4u; _19818++)
                            {
                                for (uint _19819 = 0u; _19819 < 4u; )
                                {
                                    _12367[_19818][_19819] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12401 + 16u) + (_19818 * 4u)) + _19819) * 4 + 0));
                                    _19819++;
                                    continue;
                                }
                            }
                            _19821 = true;
                            break;
                        } while(false);
                        if (_19821)
                        {
                            _19822 = _12367;
                            break;
                        }
                        _19822 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12278 = mul(float4((float2(_19057.x, 1.0f - _19057.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19057 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12337_dummy_parameter))))), 0)).x, 1.0f), _19822);
                    float _12280 = _12278.w;
                    if (abs(_12280) < 9.9999999747524270787835121154785e-07f)
                    {
                        _19823 = 0.0f;
                        break;
                    }
                    float _12291 = abs(cbFI_DeviceToViewDepth.y / ((_12278.z / _12280) - cbFI_DeviceToViewDepth.x));
                    float _12294 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19058 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12353_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _19823 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12291 - _12294) / max(max(_12291, _12294), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6362 = _19823 < 0.5f;
            }
            else
            {
                _6362 = _6355;
            }
            float4 _19842;
            if (_6362)
            {
                uint _12505_dummy_parameter;
                uint _12536_dummy_parameter;
                float4 _19843;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19057 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12505_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19058 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12536_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _19843 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _19843 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _19842 = _19843;
            }
            else
            {
                _19842 = 1.0f.xxxx;
            }
            bool _6386;
            if (_10970)
            {
                bool _12565 = all(bool2(_19054.x > 0.0f.xx.x, _19054.y > 0.0f.xx.y));
                bool _12571;
                if (_12565)
                {
                    _12571 = all(bool2(_19054.x < 1.0f.xx.x, _19054.y < 1.0f.xx.y));
                }
                else
                {
                    _12571 = _12565;
                }
                _6386 = _12571;
            }
            else
            {
                _6386 = _10970;
            }
            bool _6392;
            if (_10970)
            {
                bool _12576 = all(bool2(_19056.x > 0.0f.xx.x, _19056.y > 0.0f.xx.y));
                bool _12582;
                if (_12576)
                {
                    _12582 = all(bool2(_19056.x < 1.0f.xx.x, _19056.y < 1.0f.xx.y));
                }
                else
                {
                    _12582 = _12576;
                }
                _6392 = _12582;
            }
            else
            {
                _6392 = _10970;
            }
            bool _6398;
            if (_11002)
            {
                bool _12587 = all(bool2(_19057.x > 0.0f.xx.x, _19057.y > 0.0f.xx.y));
                bool _12593;
                if (_12587)
                {
                    _12593 = all(bool2(_19057.x < 1.0f.xx.x, _19057.y < 1.0f.xx.y));
                }
                else
                {
                    _12593 = _12587;
                }
                _6398 = _12593;
            }
            else
            {
                _6398 = _11002;
            }
            bool _6404;
            if (_11002)
            {
                bool _12598 = all(bool2(_19058.x > 0.0f.xx.x, _19058.y > 0.0f.xx.y));
                bool _12604;
                if (_12598)
                {
                    _12604 = all(bool2(_19058.x < 1.0f.xx.x, _19058.y < 1.0f.xx.y));
                }
                else
                {
                    _12604 = _12598;
                }
                _6404 = _12604;
            }
            else
            {
                _6404 = _11002;
            }
            bool _6407 = _6398 != _6404;
            bool _6413;
            if (_6407)
            {
                _6413 = _6386 || _6392;
            }
            else
            {
                _6413 = _6407;
            }
            float4 _19945;
            if (_6413)
            {
                float4 _18783 = _19842;
                _18783.z = 0.0f;
                _18783.w = 0.0f;
                _19945 = _18783;
            }
            else
            {
                _19945 = _19842;
            }
            bool _6420 = _6386 && _6332;
            bool _6423 = _6392 && _6335;
            float4 _20050;
            float3 _21124;
            if (_6420 || _6423)
            {
                float _19940;
                do
                {
                    uint4 _12743 = r_warped_motion_qdata_tp1.Load(int3(_19275, 0));
                    uint _12744 = _12743.x;
                    if (_12744 != 0u)
                    {
                        float _19939;
                        if (_12744 == 0u)
                        {
                            _19939 = -1.0f;
                        }
                        else
                        {
                            _19939 = float((_12744 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _19940 = _19939;
                        break;
                    }
                    int _19922;
                    uint _19923;
                    _19923 = _12744;
                    _19922 = -1;
                    uint _19938;
                    for (; _19922 <= 1; _19923 = _19938, _19922++)
                    {
                        _19938 = _19923;
                        for (int _19936 = -1; _19936 <= 1; )
                        {
                            _19938 = max(_19938, r_warped_motion_qdata_tp1.Load(int3(clamp(_19275 + int2(_19936, _19922), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _19936++;
                            continue;
                        }
                    }
                    if (_19923 != 0u)
                    {
                        float _19935;
                        if (_19923 == 0u)
                        {
                            _19935 = -1.0f;
                        }
                        else
                        {
                            _19935 = float((_19923 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _19940 = _19935;
                        break;
                    }
                    uint _19925;
                    _19925 = 4294967295u;
                    uint _22475;
                    for (int _19924 = 0; _19924 < 8; _19925 = _22475, _19924++)
                    {
                        int _19928 = 0;
                        for (;;)
                        {
                            if (_19928 < 5)
                            {
                                int2 _12694 = _19275 + (_1243[_19924] * _1252[_19928].xx);
                                bool _12697 = any(bool2(_12694.x < int2(0, 0).x, _12694.y < int2(0, 0).y));
                                bool _12705;
                                if (!_12697)
                                {
                                    _12705 = any(bool2(_12694.x >= cbFI_MvDepthLaneSize.x, _12694.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12705 = _12697;
                                }
                                if (_12705)
                                {
                                    _22475 = _19925;
                                    break;
                                }
                                uint4 _12783 = r_warped_motion_qdata_tp1.Load(int3(_12694, 0));
                                uint _12784 = _12783.x;
                                if (_12784 != 0u)
                                {
                                    _22475 = min(_19925, _12784);
                                    break;
                                }
                                _19928++;
                                continue;
                            }
                            else
                            {
                                _22475 = _19925;
                                break;
                            }
                        }
                    }
                    float _19927;
                    if (_19925 == 4294967295u)
                    {
                        _19927 = -1.0f;
                    }
                    else
                    {
                        float _19926;
                        if (_19925 == 0u)
                        {
                            _19926 = -1.0f;
                        }
                        else
                        {
                            _19926 = float((_19925 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _19927 = _19926;
                    }
                    _19940 = _19927;
                    break;
                } while(false);
                bool _6431 = _19940 < 0.0f;
                float _19941;
                if (_6431)
                {
                    _19941 = 0.0f;
                }
                else
                {
                    _19941 = _19940 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12805_dummy_parameter;
                uint _12837_dummy_parameter;
                float4 _19978;
                if ((_6431 && _6420) && _6423)
                {
                    uint _12869_dummy_parameter;
                    float _12893 = log(((r_depth_tm1.Load(int3(int2(floor(_19054 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12869_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12901_dummy_parameter;
                    float _12925 = log(((r_depth_tp1.Load(int3(int2(floor(_19056 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12901_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _19979;
                    if (_12893 > (_12925 + 0.07999999821186065673828125f))
                    {
                        float4 _18787 = _19945;
                        _18787.x = 0.0f;
                        _19979 = _18787;
                    }
                    else
                    {
                        float4 _19980;
                        if (_12925 > (_12893 + 0.07999999821186065673828125f))
                        {
                            float4 _18789 = _19945;
                            _18789.y = 0.0f;
                            _19980 = _18789;
                        }
                        else
                        {
                            _19980 = _19945;
                        }
                        _19979 = _19980;
                    }
                    _19978 = _19979;
                }
                else
                {
                    _19978 = _19945;
                }
                float _6483 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6485 = _19940 >= 0.0f;
                float _19961;
                if (_6485)
                {
                    _19961 = _19940 - _6483;
                }
                else
                {
                    float _19957;
                    if (_6420)
                    {
                        float _19956;
                        _19956 = 2.0f;
                        float _12983;
                        for (int _19955 = 0; _19955 < 24; _19956 = _12983, _19955++)
                        {
                            float _12947 = float(_19955 & 7) * 0.785398185253143310546875f;
                            int _12949 = _19955 >> 3;
                            int _19958;
                            if (_12949 == 0)
                            {
                                _19958 = 16;
                            }
                            else
                            {
                                _19958 = (_12949 == 1) ? 48 : 96;
                            }
                            uint _12999_dummy_parameter;
                            _12983 = min(_19956, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19054 + ((cbFI_MvDepthLaneSizeRcp * float(_19958)) * float2(cos(_12947), sin(_12947))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12999_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _19957 = _19956;
                    }
                    else
                    {
                        _19957 = 0.0f;
                    }
                    _19961 = _19957;
                }
                float _19968;
                if (_6485)
                {
                    _19968 = _19940 - _6483;
                }
                else
                {
                    float _19964;
                    if (_6423)
                    {
                        float _19963;
                        _19963 = 2.0f;
                        float _13097;
                        for (int _19962 = 0; _19962 < 24; _19963 = _13097, _19962++)
                        {
                            float _13061 = float(_19962 & 7) * 0.785398185253143310546875f;
                            int _13063 = _19962 >> 3;
                            int _19965;
                            if (_13063 == 0)
                            {
                                _19965 = 16;
                            }
                            else
                            {
                                _19965 = (_13063 == 1) ? 48 : 96;
                            }
                            uint _13129_dummy_parameter;
                            _13097 = min(_19963, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19056 + ((cbFI_MvDepthLaneSizeRcp * float(_19965)) * float2(cos(_13061), sin(_13061))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13129_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _19964 = _19963;
                    }
                    else
                    {
                        _19964 = 0.0f;
                    }
                    _19968 = _19964;
                }
                float _19969;
                if (_6420)
                {
                    uint _13161_dummy_parameter;
                    _19969 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_19054 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13161_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _19969 = 0.0f;
                }
                float _19970;
                if (_6423)
                {
                    uint _13181_dummy_parameter;
                    _19970 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_19056 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13181_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _19970 = 0.0f;
                }
                bool _6540;
                if (_6420)
                {
                    _6540 = _19969 > ((exp((_19961 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6540 = _6420;
                }
                float4 _19986;
                if (_6540)
                {
                    float4 _18791 = _19978;
                    _18791.x = 0.0f;
                    _19986 = _18791;
                }
                else
                {
                    _19986 = _19978;
                }
                bool _6552;
                if (_6423)
                {
                    _6552 = _19970 > ((exp((_19968 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6552 = _6423;
                }
                float4 _19988;
                if (_6552)
                {
                    float4 _18793 = _19986;
                    _18793.y = 0.0f;
                    _19988 = _18793;
                }
                else
                {
                    _19988 = _19986;
                }
                float4 _20051;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6485)
                {
                    bool _6572;
                    if (_6420)
                    {
                        _6572 = _19969 < ((exp((_19961 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6572 = _6420;
                    }
                    float4 _19990;
                    if (_6572)
                    {
                        float4 _18795 = _19988;
                        _18795.x = 0.0f;
                        _19990 = _18795;
                    }
                    else
                    {
                        _19990 = _19988;
                    }
                    bool _6584;
                    if (_6423)
                    {
                        _6584 = _19970 < ((exp((_19968 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6584 = _6423;
                    }
                    float4 _20052;
                    if (_6584)
                    {
                        float4 _18797 = _19990;
                        _18797.y = 0.0f;
                        _20052 = _18797;
                    }
                    else
                    {
                        _20052 = _19990;
                    }
                    _20051 = _20052;
                }
                else
                {
                    _20051 = _19988;
                }
                _21124 = float3(_19941, log(((r_depth_tm1.Load(int3(int2(floor(_19054 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12805_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_19056 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12837_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _20050 = _20051;
            }
            else
            {
                _21124 = float3(0.0f, 0.0f, 0.5f);
                _20050 = _19945;
            }
            bool _6595 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6344;
            bool _6601;
            if (_6595)
            {
                _6601 = _6398 || _6404;
            }
            else
            {
                _6601 = _6595;
            }
            float4 _20093;
            if (_6601)
            {
                float _20045;
                do
                {
                    uint4 _13361 = r_warped_motion_qdata_tp1.Load(int3(_19275, 0));
                    uint _13362 = _13361.x;
                    if (_13362 != 0u)
                    {
                        float _20044;
                        if (_13362 == 0u)
                        {
                            _20044 = -1.0f;
                        }
                        else
                        {
                            _20044 = float((_13362 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20045 = _20044;
                        break;
                    }
                    int _20027;
                    uint _20028;
                    _20028 = _13362;
                    _20027 = -1;
                    uint _20043;
                    for (; _20027 <= 1; _20028 = _20043, _20027++)
                    {
                        _20043 = _20028;
                        for (int _20041 = -1; _20041 <= 1; )
                        {
                            _20043 = max(_20043, r_warped_motion_qdata_tp1.Load(int3(clamp(_19275 + int2(_20041, _20027), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20041++;
                            continue;
                        }
                    }
                    if (_20028 != 0u)
                    {
                        float _20040;
                        if (_20028 == 0u)
                        {
                            _20040 = -1.0f;
                        }
                        else
                        {
                            _20040 = float((_20028 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20045 = _20040;
                        break;
                    }
                    uint _20030;
                    _20030 = 4294967295u;
                    uint _22476;
                    for (int _20029 = 0; _20029 < 8; _20030 = _22476, _20029++)
                    {
                        int _20033 = 0;
                        for (;;)
                        {
                            if (_20033 < 5)
                            {
                                int2 _13312 = _19275 + (_1243[_20029] * _1252[_20033].xx);
                                bool _13315 = any(bool2(_13312.x < int2(0, 0).x, _13312.y < int2(0, 0).y));
                                bool _13323;
                                if (!_13315)
                                {
                                    _13323 = any(bool2(_13312.x >= cbFI_MvDepthLaneSize.x, _13312.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13323 = _13315;
                                }
                                if (_13323)
                                {
                                    _22476 = _20030;
                                    break;
                                }
                                uint4 _13401 = r_warped_motion_qdata_tp1.Load(int3(_13312, 0));
                                uint _13402 = _13401.x;
                                if (_13402 != 0u)
                                {
                                    _22476 = min(_20030, _13402);
                                    break;
                                }
                                _20033++;
                                continue;
                            }
                            else
                            {
                                _22476 = _20030;
                                break;
                            }
                        }
                    }
                    float _20032;
                    if (_20030 == 4294967295u)
                    {
                        _20032 = -1.0f;
                    }
                    else
                    {
                        float _20031;
                        if (_20030 == 0u)
                        {
                            _20031 = -1.0f;
                        }
                        else
                        {
                            _20031 = float((_20030 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20032 = _20031;
                    }
                    _20045 = _20032;
                    break;
                } while(false);
                float4 _20094;
                if (_20045 >= 0.0f)
                {
                    float _13423 = (exp((_20045 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6620;
                    if (_6398)
                    {
                        uint _13430_dummy_parameter;
                        _6620 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19057 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13430_dummy_parameter))))), 0)).x) > _13423;
                    }
                    else
                    {
                        _6620 = _6398;
                    }
                    float4 _20063;
                    if (_6620)
                    {
                        float4 _18799 = _20050;
                        _18799.z = 0.0f;
                        _20063 = _18799;
                    }
                    else
                    {
                        _20063 = _20050;
                    }
                    bool _6632;
                    if (_6404)
                    {
                        uint _13450_dummy_parameter;
                        _6632 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19058 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13450_dummy_parameter))))), 0)).x) > _13423;
                    }
                    else
                    {
                        _6632 = _6404;
                    }
                    float4 _20095;
                    if (_6632)
                    {
                        float4 _18801 = _20063;
                        _18801.w = 0.0f;
                        _20095 = _18801;
                    }
                    else
                    {
                        _20095 = _20063;
                    }
                    _20094 = _20095;
                }
                else
                {
                    _20094 = _20050;
                }
                _20093 = _20094;
            }
            else
            {
                _20093 = _20050;
            }
            bool _6640 = _6386 != _6392;
            bool _6647;
            if (_6640)
            {
                _6647 = _6386 ? _6332 : _6335;
            }
            else
            {
                _6647 = _6640;
            }
            bool _6654;
            if (_6647)
            {
                _6654 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6654 = _6647;
            }
            float4 _20196;
            if (_6654)
            {
                bool2 _6659 = _6386.xx;
                float2 _6660 = float2(_6659.x ? _19054.x : _19056.x, _6659.y ? _19054.y : _19056.y);
                float _20077;
                if (_6386)
                {
                    uint _13470_dummy_parameter;
                    _20077 = r_depth_tm1.Load(int3(int2(floor(_6660 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13470_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13486_dummy_parameter;
                    _20077 = r_depth_tp1.Load(int3(int2(floor(_6660 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13486_dummy_parameter))))), 0)).x;
                }
                float4x4 _20084;
                if (_6386)
                {
                    float4x4 _20073;
                    do
                    {
                        float4x4 _13500;
                        bool _20072;
                        do
                        {
                            _13500 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20072 = false;
                                break;
                            }
                            uint _13534 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13534 + 32u) * 4 + 0) != 1u)
                            {
                                _20072 = false;
                                break;
                            }
                            uint _20069;
                            _20069 = 0u;
                            for (; _20069 < 4u; _20069++)
                            {
                                for (uint _20070 = 0u; _20070 < 4u; )
                                {
                                    _13500[_20069][_20070] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13534 + 16u) + (_20069 * 4u)) + _20070) * 4 + 0));
                                    _20070++;
                                    continue;
                                }
                            }
                            _20072 = true;
                            break;
                        } while(false);
                        if (_20072)
                        {
                            _20073 = _13500;
                            break;
                        }
                        _20073 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20084 = _20073;
                }
                else
                {
                    float4x4 _20068;
                    do
                    {
                        float4x4 _13606;
                        bool _20067;
                        do
                        {
                            _13606 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20067 = false;
                                break;
                            }
                            uint _13640 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13640 + 32u) * 4 + 0) != 1u)
                            {
                                _20067 = false;
                                break;
                            }
                            uint _20064;
                            _20064 = 0u;
                            for (; _20064 < 4u; _20064++)
                            {
                                for (uint _20065 = 0u; _20065 < 4u; )
                                {
                                    _13606[_20064][_20065] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13640 + (_20064 * 4u)) + _20065) * 4 + 0));
                                    _20065++;
                                    continue;
                                }
                            }
                            _20067 = true;
                            break;
                        } while(false);
                        if (_20067)
                        {
                            _20068 = _13606;
                            break;
                        }
                        _20068 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20084 = _20068;
                }
                float2 _20085;
                do
                {
                    float _13717 = _6660.x;
                    float _13720 = 1.0f - _6660.y;
                    float4 _13731 = mul(float4((float2(_13717, _13720) * 2.0f) - 1.0f.xx, _20077, 1.0f), _20084);
                    float _13733 = _13731.w;
                    if (!(_13733 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20085 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13746 = ((_13731.xy / _13733.xx) + 1.0f.xx) * 0.5f;
                    _20085 = float2(_13746.x - _13717, _13720 - _13746.y);
                    break;
                } while(false);
                float2 _6690 = float2(cbFI_DisplaySize);
                float4 _20197;
                if (!(length(((_6660 + _20085) - float2(_6659.x ? _19056.x : _19054.x, _6659.y ? _19056.y : _19054.y)) * _6690) <= ((0.100000001490116119384765625f * length(_20085 * _6690)) + 8.0f)))
                {
                    float4 _20198;
                    if (_6386)
                    {
                        float4 _18811 = _20093;
                        _18811.x = 0.0f;
                        _20198 = _18811;
                    }
                    else
                    {
                        float4 _18813 = _20093;
                        _18813.y = 0.0f;
                        _20198 = _18813;
                    }
                    _20197 = _20198;
                }
                else
                {
                    _20197 = _20093;
                }
                _20196 = _20197;
            }
            else
            {
                _20196 = _20093;
            }
            float4 _6715 = _19807 * _20196;
            float _6717 = dot(_6715, 1.0f.xxxx);
            float4 _20538;
            bool _20844;
            if (_6717 > 0.0f)
            {
                _20844 = _19498;
                _20538 = _6715 / _6717.xxxx;
            }
            else
            {
                bool _6728 = any(bool4(_20196.x < 1.0f.xxxx.x, _20196.y < 1.0f.xxxx.y, _20196.z < 1.0f.xxxx.z, _20196.w < 1.0f.xxxx.w));
                if (_6728)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13768;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13768);
                    }
                }
                bool4 _22781 = _6728.xxxx;
                _20844 = _6728 ? true : _19498;
                _20538 = float4(_22781.x ? 0.0f.xxxx.x : _19807.x, _22781.y ? 0.0f.xxxx.y : _19807.y, _22781.z ? 0.0f.xxxx.z : _19807.z, _22781.w ? 0.0f.xxxx.w : _19807.w);
            }
            _21015 = _21124;
            _20843 = _20844;
            _20537 = _20538;
        }
        else
        {
            _21015 = float3(0.0f, 0.0f, 0.5f);
            _20843 = _19498;
            _20537 = _19807;
        }
        uint _6737 = (cbFI_pad0 >> 24u) & 31u;
        uint _6741 = (cbFI_pad0 >> 16u) & 255u;
        bool _6743 = _6737 != 0u;
        bool _6745 = _6741 == 12u;
        bool _6748 = _6741 == 13u;
        float4 _20558;
        if ((_6743 || _6745) || _6748)
        {
            float _20204;
            do
            {
                bool _13852 = all(bool2(_19057.x > 0.0f.xx.x, _19057.y > 0.0f.xx.y));
                bool _13858;
                if (_13852)
                {
                    _13858 = all(bool2(_19057.x < 1.0f.xx.x, _19057.y < 1.0f.xx.y));
                }
                else
                {
                    _13858 = _13852;
                }
                bool _13789 = !_13858;
                bool _13796;
                if (!_13789)
                {
                    bool _13863 = all(bool2(_19058.x > 0.0f.xx.x, _19058.y > 0.0f.xx.y));
                    bool _13869;
                    if (_13863)
                    {
                        _13869 = all(bool2(_19058.x < 1.0f.xx.x, _19058.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13869 = _13863;
                    }
                    _13796 = !_13869;
                }
                else
                {
                    _13796 = _13789;
                }
                if (_13796)
                {
                    _20204 = 0.0f;
                    break;
                }
                uint _13876_dummy_parameter;
                uint _13892_dummy_parameter;
                float4x4 _20203;
                do
                {
                    float4x4 _13906;
                    bool _20202;
                    do
                    {
                        _13906 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20202 = false;
                            break;
                        }
                        uint _13940 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_13940 + 32u) * 4 + 0) != 1u)
                        {
                            _20202 = false;
                            break;
                        }
                        uint _20199;
                        _20199 = 0u;
                        for (; _20199 < 4u; _20199++)
                        {
                            for (uint _20200 = 0u; _20200 < 4u; )
                            {
                                _13906[_20199][_20200] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13940 + 16u) + (_20199 * 4u)) + _20200) * 4 + 0));
                                _20200++;
                                continue;
                            }
                        }
                        _20202 = true;
                        break;
                    } while(false);
                    if (_20202)
                    {
                        _20203 = _13906;
                        break;
                    }
                    _20203 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13817 = mul(float4((float2(_19057.x, 1.0f - _19057.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19057 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13876_dummy_parameter))))), 0)).x, 1.0f), _20203);
                float _13819 = _13817.w;
                if (abs(_13819) < 9.9999999747524270787835121154785e-07f)
                {
                    _20204 = 0.0f;
                    break;
                }
                float _13830 = abs(cbFI_DeviceToViewDepth.y / ((_13817.z / _13819) - cbFI_DeviceToViewDepth.x));
                float _13833 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19058 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13892_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20204 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13830 - _13833) / max(max(_13830, _13833), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14042 = all(bool2(_19058.x > 0.0f.xx.x, _19058.y > 0.0f.xx.y));
            bool _14048;
            if (_14042)
            {
                _14048 = all(bool2(_19058.x < 1.0f.xx.x, _19058.y < 1.0f.xx.y));
            }
            else
            {
                _14048 = _14042;
            }
            float _20205;
            if (_14048)
            {
                uint _14055_dummy_parameter;
                _20205 = length((_7868 + (r_motion_tp1.Load(int3(int2(floor(_19058 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14055_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20205 = 1000000.0f;
            }
            float _20220;
            if ((_6737 & 1u) != 0u)
            {
                _20220 = _20204;
            }
            else
            {
                _20220 = 1.0f;
            }
            float _20221;
            if ((_6737 & 2u) != 0u)
            {
                _20221 = _20220 * (1.0f - smoothstep(2.0f, 8.0f, _20205));
            }
            else
            {
                _20221 = _20220;
            }
            float _20222;
            if ((_6737 & 4u) != 0u)
            {
                _20222 = _20221 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8589 - _8597) - length(_8573 - _8581))));
            }
            else
            {
                _20222 = _20221;
            }
            float _20552;
            if ((_6737 & 8u) != 0u)
            {
                _20552 = lerp(1.0f, _20222, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8573 - _8581)));
            }
            else
            {
                _20552 = _20222;
            }
            bool _6823 = (_6737 & 16u) != 0u;
            bool _6832;
            if (_6823)
            {
                _6832 = length(_19052 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6832 = _6823;
            }
            float _22783 = _6832 ? 1.0f : _20552;
            bool _6838 = _6743 && _10970;
            bool _6843;
            if (_6838)
            {
                bool _14080 = all(bool2(_19054.x > 0.0f.xx.x, _19054.y > 0.0f.xx.y));
                bool _14086;
                if (_14080)
                {
                    _14086 = all(bool2(_19054.x < 1.0f.xx.x, _19054.y < 1.0f.xx.y));
                }
                else
                {
                    _14086 = _14080;
                }
                _6843 = _14086;
            }
            else
            {
                _6843 = _6838;
            }
            bool _6848;
            if (_6843)
            {
                bool _14091 = all(bool2(_19056.x > 0.0f.xx.x, _19056.y > 0.0f.xx.y));
                bool _14097;
                if (_14091)
                {
                    _14097 = all(bool2(_19056.x < 1.0f.xx.x, _19056.y < 1.0f.xx.y));
                }
                else
                {
                    _14097 = _14091;
                }
                _6848 = _14097;
            }
            else
            {
                _6848 = _6843;
            }
            float4 _20559;
            if (_6848)
            {
                float _6854 = _20537.x + _20537.y;
                float _6863 = (_20537.z + _20537.w) * (1.0f - _22783);
                float _20555;
                if (_6854 > 9.9999997473787516355514526367188e-06f)
                {
                    _20555 = _20537.x / _6854;
                }
                else
                {
                    _20555 = _5593;
                }
                _20559 = float4(_20537.x + (_6863 * _20555), _20537.y + (_6863 * (1.0f - _20555)), _20537.zw * _22783);
            }
            else
            {
                _20559 = _20537;
            }
            _20558 = _20559;
        }
        else
        {
            _20558 = _20537;
        }
        float3 _6924 = (((_8573 * _20558.x) + (_8581 * _20558.y)) + (_8589 * _20558.z)) + (_8597 * _20558.w);
        float3 _22092;
        if (_5609 && (_20573 > 0.0f))
        {
            uint _14104_dummy_parameter;
            float2 _14119 = r_motion_tp1.Load(int3(int2(floor(_5368 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14104_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _20835;
            if (_7896)
            {
                float2 _14164 = clamp((((_19031 + (_14119 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14167 = tan(_14164.x);
                _20835 = (float2(_14167 / cbFI_DeviceToViewDepth.z, (tan(_14164.y) * sqrt(1.0f + (_14167 * _14167))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _20835 = _19031 + (_14119 * cbFI_Timestep);
            }
            float2 _20836;
            if (_7896)
            {
                float2 _14243 = clamp((((_19031 + (_14119 * _5583)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14246 = tan(_14243.x);
                _20836 = (float2(_14246 / cbFI_DeviceToViewDepth.z, (tan(_14243.y) * sqrt(1.0f + (_14246 * _14246))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _20836 = _19031 + (_14119 * _5583);
            }
            _22092 = lerp(_6924, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _20835, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _20836, 0.0f).xyz, cbFI_Timestep.xxx), _20573.xxx);
        }
        else
        {
            _22092 = _6924;
        }
        float3 _22091;
        if (_20843)
        {
            float3 _14288 = r_current_interpolation_source.Load(int3(_4869, 0)).xyz;
            float3 _22093;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _10970)
            {
                uint _14295_dummy_parameter;
                float _20966;
                _20966 = r_depth_tm1.Load(int3(int2(floor(_19054 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14295_dummy_parameter))))), 0)).x;
                float _7005;
                for (int _20965 = 0; _20965 < 24; _20966 = _7005, _20965++)
                {
                    float _6977 = float(_20965 & 7) * 0.785398185253143310546875f;
                    int _6979 = _20965 >> 3;
                    int _22318;
                    if (_6979 == 0)
                    {
                        _22318 = 16;
                    }
                    else
                    {
                        _22318 = (_6979 == 1) ? 48 : 96;
                    }
                    uint _14315_dummy_parameter;
                    _7005 = max(_20966, r_depth_tm1.Load(int3(int2(floor(clamp(_19054 + ((cbFI_MvDepthLaneSizeRcp * float(_22318)) * float2(cos(_6977), sin(_6977))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14315_dummy_parameter))))), 0)).x);
                }
                float2 _20967;
                do
                {
                    float _14337 = 1.0f - _19054.y;
                    float4 _14348 = mul(float4((float2(_19054.x, _14337) * 2.0f) - 1.0f.xx, _20966, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14350 = _14348.w;
                    if (!(_14350 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20967 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14363 = ((_14348.xy / _14350.xx) + 1.0f.xx) * 0.5f;
                    _20967 = float2(_14363.x - _19054.x, _14337 - _14363.y);
                    break;
                } while(false);
                float2 _7016 = _19054 + _20967;
                bool _14381 = all(bool2(_7016.x > 0.0f.xx.x, _7016.y > 0.0f.xx.y));
                bool _14387;
                if (_14381)
                {
                    _14387 = all(bool2(_7016.x < 1.0f.xx.x, _7016.y < 1.0f.xx.y));
                }
                else
                {
                    _14387 = _14381;
                }
                float3 _22094;
                if (_14387)
                {
                    float _7022 = abs(cbFI_DeviceToViewDepth.y / (_20966 - cbFI_DeviceToViewDepth.x));
                    uint _14407_dummy_parameter;
                    int2 _14407 = int2(spvTextureSize(r_depth_m2, uint(0), _14407_dummy_parameter));
                    float _7026 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7016 * float2(_14407))), int2(0, 0), _14407 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22099;
                    if (abs(_7026 - _7022) <= (0.20000000298023223876953125f * max(_7026, _7022)))
                    {
                        uint _14441_dummy_parameter;
                        int2 _14441 = int2(spvTextureSize(r_colour_m2, uint(0), _14441_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14464;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14464);
                        }
                        _22099 = r_colour_m2.Load(int3(clamp(int2(floor(_7016 * float2(_14441))), int2(0, 0), _14441 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14474;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14474);
                        }
                        _22099 = _14288;
                    }
                    _22094 = _22099;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14484;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14484);
                    }
                    _22094 = _14288;
                }
                _22093 = _22094;
            }
            else
            {
                _22093 = _14288;
            }
            _22091 = _22093;
        }
        else
        {
            _22091 = _22092;
        }
        bool _7051 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22090;
        float _22166;
        if (_7051)
        {
            float _14670;
            float2 _7055 = float2(cbFI_DisplaySize);
            float3 _21006;
            do
            {
                bool _14731;
                float4x4 _20974;
                do
                {
                    float4x4 _14707;
                    bool _20973;
                    do
                    {
                        _14707 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14731 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14731)
                        {
                            _20973 = false;
                            break;
                        }
                        uint _14741 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14741 + 32u) * 4 + 0) != 1u)
                        {
                            _20973 = false;
                            break;
                        }
                        uint _20970;
                        _20970 = 0u;
                        for (; _20970 < 4u; _20970++)
                        {
                            for (uint _20971 = 0u; _20971 < 4u; )
                            {
                                _14707[_20970][_20971] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14741 + (_20970 * 4u)) + _20971) * 4 + 0));
                                _20971++;
                                continue;
                            }
                        }
                        _20973 = true;
                        break;
                    } while(false);
                    if (_20973)
                    {
                        _20974 = _14707;
                        break;
                    }
                    _20974 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float _14818;
                float _14821;
                float4 _14831;
                float4x4 _14538 = spvInverse(_20974);
                float2 _20975;
                do
                {
                    _14818 = _5368.x;
                    _14821 = 1.0f - _5368.y;
                    _14831 = float4((float2(_14818, _14821) * 2.0f) - 1.0f.xx, 0.99999988079071044921875f, 1.0f);
                    float4 _14832 = mul(_14831, _20974);
                    float _14834 = _14832.w;
                    if (!(_14834 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20975 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14847 = ((_14832.xy / _14834.xx) + 1.0f.xx) * 0.5f;
                    _20975 = float2(_14847.x - _14818, _14821 - _14847.y);
                    break;
                } while(false);
                float2 _20976;
                do
                {
                    float4 _14884 = mul(_14831, _14538);
                    float _14886 = _14884.w;
                    if (!(_14886 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20976 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14899 = ((_14884.xy / _14886.xx) + 1.0f.xx) * 0.5f;
                    _20976 = float2(_14899.x - _14818, _14821 - _14899.y);
                    break;
                } while(false);
                float2 _14546 = abs(_20975);
                bool2 _22784 = any(bool2(_14546.x > 4.0f.xx.x, _14546.y > 4.0f.xx.y)).xx;
                float2 _14552 = abs(_20976);
                bool2 _22786 = any(bool2(_14552.x > 4.0f.xx.x, _14552.y > 4.0f.xx.y)).xx;
                float2 _14913[3];
                _14913[0] = _5368;
                float2 _15033 = clamp(_5368, 0.0f.xx, 1.0f.xx);
                uint _15041_dummy_parameter;
                _14913[1] = _5368 - ((r_motion_tp1.Load(int3(int2(floor(_15033 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15041_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5593);
                _14913[2] = _5368 - (float2(_22784.x ? 0.0f.xx.x : _20975.x, _22784.y ? 0.0f.xx.y : _20975.y) * _5593);
                float _20982;
                float2 _20983;
                _20983 = _5368;
                _20982 = 1000000000.0f;
                float _22788;
                float2 _22790;
                float _22791;
                int _20981 = 0;
                float _22310 = -1.0f;
                for (; _20981 < 3; _22310 = _22788, _20983 = _22790, _20982 = _22791, _20981++)
                {
                    float2 _22300;
                    _22300 = _14913[_20981];
                    for (int _22299 = 0; _22299 < 30; )
                    {
                        uint _15555_dummy_parameter;
                        _22300 += (((_5368 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_22300, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15555_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5593)) - _22300) * 0.699999988079071044921875f);
                        _22299++;
                        continue;
                    }
                    float2 _15985 = clamp(_22300, 0.0f.xx, 1.0f.xx);
                    uint _15993_dummy_parameter;
                    bool _16423 = all(bool2(_22300.x > 0.0f.xx.x, _22300.y > 0.0f.xx.y));
                    bool _16429;
                    if (_16423)
                    {
                        _16429 = all(bool2(_22300.x < 1.0f.xx.x, _22300.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _16429 = _16423;
                    }
                    float _22302;
                    if (_16429)
                    {
                        _22302 = length(((_22300 + ((r_motion_tp1.Load(int3(int2(floor(_15985 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15993_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5593)) - _5368) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22302 = 1000000000.0f;
                    }
                    uint _16440_dummy_parameter;
                    float _16480 = log(((r_depth_tp1.Load(int3(int2(floor(_15985 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16440_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _14993 = _22302 < 0.3499999940395355224609375f;
                    bool _14995 = _20982 < 0.3499999940395355224609375f;
                    bool _15005;
                    if (_14993)
                    {
                        _15005 = (!_14995) || (_16480 > _22310);
                    }
                    else
                    {
                        _15005 = _14993;
                    }
                    bool _15018;
                    if (!_15005)
                    {
                        _15018 = ((!_14993) && (!_14995)) && (_22302 < _20982);
                    }
                    else
                    {
                        _15018 = _15005;
                    }
                    _22788 = _15018 ? _16480 : _22310;
                    bool2 _22789 = _15018.xx;
                    _22790 = float2(_22789.x ? _22300.x : _20983.x, _22789.y ? _22300.y : _20983.y);
                    _22791 = _15018 ? _22302 : _20982;
                }
                float2 _16482[3];
                _16482[0] = _5368;
                float2 _21002;
                do
                {
                    bool _20992;
                    do
                    {
                        bool _16729 = all(bool2(_15033.x > 0.0f.xx.x, _15033.y > 0.0f.xx.y));
                        bool _16735;
                        if (_16729)
                        {
                            _16735 = all(bool2(_15033.x < 1.0f.xx.x, _15033.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _16735 = _16729;
                        }
                        if (!_16735)
                        {
                            _20992 = false;
                            break;
                        }
                        uint _16742_dummy_parameter;
                        float4x4 _20990;
                        do
                        {
                            float4x4 _16756;
                            bool _20989;
                            do
                            {
                                _16756 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14731)
                                {
                                    _20989 = false;
                                    break;
                                }
                                uint _16790 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_16790 + 32u) * 4 + 0) != 1u)
                                {
                                    _20989 = false;
                                    break;
                                }
                                uint _20986;
                                _20986 = 0u;
                                for (; _20986 < 4u; _20986++)
                                {
                                    for (uint _20987 = 0u; _20987 < 4u; )
                                    {
                                        _16756[_20986][_20987] = asfloat(rw_nfru_diagnostics.Load<uint>(((_16790 + (_20986 * 4u)) + _20987) * 4 + 0));
                                        _20987++;
                                        continue;
                                    }
                                }
                                _20989 = true;
                                break;
                            } while(false);
                            if (_20989)
                            {
                                _20990 = _16756;
                                break;
                            }
                            _20990 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _20991;
                        do
                        {
                            float _16867 = _15033.x;
                            float _16870 = 1.0f - _15033.y;
                            float4 _16881 = mul(float4((float2(_16867, _16870) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15033 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16742_dummy_parameter))))), 0)).x, 1.0f), _20990);
                            float _16883 = _16881.w;
                            if (!(_16883 > 9.9999999747524270787835121154785e-07f))
                            {
                                _20991 = 1000000.0f.xx;
                                break;
                            }
                            float2 _16896 = ((_16881.xy / _16883.xx) + 1.0f.xx) * 0.5f;
                            _20991 = float2(_16896.x - _16867, _16870 - _16896.y);
                            break;
                        } while(false);
                        float2 _16693 = abs(_20991);
                        if (any(bool2(_16693.x > 100000.0f.xx.x, _16693.y > 100000.0f.xx.y)))
                        {
                            _20992 = false;
                            break;
                        }
                        float _16701 = length(_20991 * _7055);
                        uint _16916_dummy_parameter;
                        bool _16715 = _16701 > ((8.0f * _7055.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _16722;
                        if (_16715)
                        {
                            _16722 = length((r_motion_tp1.Load(int3(int2(floor(_15033 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16916_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7055) < (0.20000000298023223876953125f * _16701);
                        }
                        else
                        {
                            _16722 = _16715;
                        }
                        _20992 = _16722;
                        break;
                    } while(false);
                    if (_20992)
                    {
                        uint _16947_dummy_parameter;
                        _21002 = -(r_motion_tp1.Load(int3(int2(floor(_15033 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16947_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _16974_dummy_parameter;
                    float2 _21001;
                    do
                    {
                        float _16993 = _15033.x;
                        float _16996 = 1.0f - _15033.y;
                        float4 _17007 = mul(float4((float2(_16993, _16996) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15033 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _16974_dummy_parameter))))), 0)).x, 1.0f), _14538);
                        float _17009 = _17007.w;
                        if (!(_17009 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21001 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17022 = ((_17007.xy / _17009.xx) + 1.0f.xx) * 0.5f;
                        _21001 = float2(_17022.x - _16993, _16996 - _17022.y);
                        break;
                    } while(false);
                    float2 _16660 = abs(_21001);
                    bool2 _16664 = any(bool2(_16660.x > 4.0f.xx.x, _16660.y > 4.0f.xx.y)).xx;
                    _21002 = float2(_16664.x ? 0.0f.xx.x : _21001.x, _16664.y ? 0.0f.xx.y : _21001.y);
                    break;
                } while(false);
                _16482[1] = _5368 - (_21002 * cbFI_Timestep);
                _16482[2] = _5368 - (float2(_22786.x ? 0.0f.xx.x : _20976.x, _22786.y ? 0.0f.xx.y : _20976.y) * cbFI_Timestep);
                float _21004;
                float2 _21005;
                _21005 = _5368;
                _21004 = 1000000000.0f;
                float _22792;
                float2 _22794;
                float _22795;
                float4x4 _17270;
                float4x4 _17708;
                int _21003 = 0;
                float _22237 = -1.0f;
                for (; _21003 < 3; _22237 = _22792, _21005 = _22794, _21004 = _22795, _21003++)
                {
                    float2 _22187;
                    _22187 = _16482[_21003];
                    float2 _17079;
                    for (int _22186 = 0; _22186 < 30; _22187 = _17079, _22186++)
                    {
                        float2 _22278;
                        do
                        {
                            float2 _17159 = clamp(_22187, 0.0f.xx, 1.0f.xx);
                            bool _22268;
                            do
                            {
                                bool _17243 = all(bool2(_17159.x > 0.0f.xx.x, _17159.y > 0.0f.xx.y));
                                bool _17249;
                                if (_17243)
                                {
                                    _17249 = all(bool2(_17159.x < 1.0f.xx.x, _17159.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17249 = _17243;
                                }
                                if (!_17249)
                                {
                                    _22268 = false;
                                    break;
                                }
                                uint _17256_dummy_parameter;
                                float4x4 _22266;
                                do
                                {
                                    bool _22265;
                                    do
                                    {
                                        _17270 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14731)
                                        {
                                            _22265 = false;
                                            break;
                                        }
                                        uint _17304 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17304 + 32u) * 4 + 0) != 1u)
                                        {
                                            _22265 = false;
                                            break;
                                        }
                                        uint _22262;
                                        _22262 = 0u;
                                        for (; _22262 < 4u; _22262++)
                                        {
                                            for (uint _22263 = 0u; _22263 < 4u; )
                                            {
                                                _17270[_22262][_22263] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17304 + (_22262 * 4u)) + _22263) * 4 + 0));
                                                _22263++;
                                                continue;
                                            }
                                        }
                                        _22265 = true;
                                        break;
                                    } while(false);
                                    if (_22265)
                                    {
                                        _22266 = _17270;
                                        break;
                                    }
                                    _22266 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _22267;
                                do
                                {
                                    float _17381 = _17159.x;
                                    float _17384 = 1.0f - _17159.y;
                                    float4 _17395 = mul(float4((float2(_17381, _17384) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17159 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17256_dummy_parameter))))), 0)).x, 1.0f), _22266);
                                    float _17397 = _17395.w;
                                    if (!(_17397 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _22267 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _17410 = ((_17395.xy / _17397.xx) + 1.0f.xx) * 0.5f;
                                    _22267 = float2(_17410.x - _17381, _17384 - _17410.y);
                                    break;
                                } while(false);
                                float2 _17207 = abs(_22267);
                                if (any(bool2(_17207.x > 100000.0f.xx.x, _17207.y > 100000.0f.xx.y)))
                                {
                                    _22268 = false;
                                    break;
                                }
                                float _17215 = length(_22267 * _7055);
                                uint _17430_dummy_parameter;
                                bool _17229 = _17215 > ((8.0f * _7055.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17236;
                                if (_17229)
                                {
                                    _17236 = length((r_motion_tp1.Load(int3(int2(floor(_17159 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17430_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7055) < (0.20000000298023223876953125f * _17215);
                                }
                                else
                                {
                                    _17236 = _17229;
                                }
                                _22268 = _17236;
                                break;
                            } while(false);
                            if (_22268)
                            {
                                uint _17461_dummy_parameter;
                                _22278 = -(r_motion_tp1.Load(int3(int2(floor(_17159 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17461_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _17488_dummy_parameter;
                            float2 _22277;
                            do
                            {
                                float _17507 = _17159.x;
                                float _17510 = 1.0f - _17159.y;
                                float4 _17521 = mul(float4((float2(_17507, _17510) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17159 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17488_dummy_parameter))))), 0)).x, 1.0f), _14538);
                                float _17523 = _17521.w;
                                if (!(_17523 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22277 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17536 = ((_17521.xy / _17523.xx) + 1.0f.xx) * 0.5f;
                                _22277 = float2(_17536.x - _17507, _17510 - _17536.y);
                                break;
                            } while(false);
                            float2 _17174 = abs(_22277);
                            bool2 _17178 = any(bool2(_17174.x > 4.0f.xx.x, _17174.y > 4.0f.xx.y)).xx;
                            _22278 = float2(_17178.x ? 0.0f.xx.x : _22277.x, _17178.y ? 0.0f.xx.y : _22277.y);
                            break;
                        } while(false);
                        _17079 = _22187 + (((_5368 - (_22278 * cbFI_Timestep)) - _22187) * 0.699999988079071044921875f);
                    }
                    float2 _17597;
                    float2 _22204;
                    do
                    {
                        _17597 = clamp(_22187, 0.0f.xx, 1.0f.xx);
                        bool _22194;
                        do
                        {
                            bool _17681 = all(bool2(_17597.x > 0.0f.xx.x, _17597.y > 0.0f.xx.y));
                            bool _17687;
                            if (_17681)
                            {
                                _17687 = all(bool2(_17597.x < 1.0f.xx.x, _17597.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _17687 = _17681;
                            }
                            if (!_17687)
                            {
                                _22194 = false;
                                break;
                            }
                            uint _17694_dummy_parameter;
                            float4x4 _22192;
                            do
                            {
                                bool _22191;
                                do
                                {
                                    _17708 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14731)
                                    {
                                        _22191 = false;
                                        break;
                                    }
                                    uint _17742 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_17742 + 32u) * 4 + 0) != 1u)
                                    {
                                        _22191 = false;
                                        break;
                                    }
                                    uint _22188;
                                    _22188 = 0u;
                                    for (; _22188 < 4u; _22188++)
                                    {
                                        for (uint _22189 = 0u; _22189 < 4u; )
                                        {
                                            _17708[_22188][_22189] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17742 + (_22188 * 4u)) + _22189) * 4 + 0));
                                            _22189++;
                                            continue;
                                        }
                                    }
                                    _22191 = true;
                                    break;
                                } while(false);
                                if (_22191)
                                {
                                    _22192 = _17708;
                                    break;
                                }
                                _22192 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _22193;
                            do
                            {
                                float _17822 = 1.0f - _17597.y;
                                float4 _17833 = mul(float4((float2(_17597.x, _17822) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17597 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17694_dummy_parameter))))), 0)).x, 1.0f), _22192);
                                float _17835 = _17833.w;
                                if (!(_17835 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22193 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17848 = ((_17833.xy / _17835.xx) + 1.0f.xx) * 0.5f;
                                _22193 = float2(_17848.x - _17597.x, _17822 - _17848.y);
                                break;
                            } while(false);
                            float2 _17645 = abs(_22193);
                            if (any(bool2(_17645.x > 100000.0f.xx.x, _17645.y > 100000.0f.xx.y)))
                            {
                                _22194 = false;
                                break;
                            }
                            float _17653 = length(_22193 * _7055);
                            uint _17868_dummy_parameter;
                            bool _17667 = _17653 > ((8.0f * _7055.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _17674;
                            if (_17667)
                            {
                                _17674 = length((r_motion_tp1.Load(int3(int2(floor(_17597 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17868_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7055) < (0.20000000298023223876953125f * _17653);
                            }
                            else
                            {
                                _17674 = _17667;
                            }
                            _22194 = _17674;
                            break;
                        } while(false);
                        if (_22194)
                        {
                            uint _17899_dummy_parameter;
                            _22204 = -(r_motion_tp1.Load(int3(int2(floor(_17597 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17899_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _17926_dummy_parameter;
                        float2 _22203;
                        do
                        {
                            float _17948 = 1.0f - _17597.y;
                            float4 _17959 = mul(float4((float2(_17597.x, _17948) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17597 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17926_dummy_parameter))))), 0)).x, 1.0f), _14538);
                            float _17961 = _17959.w;
                            if (!(_17961 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22203 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17974 = ((_17959.xy / _17961.xx) + 1.0f.xx) * 0.5f;
                            _22203 = float2(_17974.x - _17597.x, _17948 - _17974.y);
                            break;
                        } while(false);
                        float2 _17612 = abs(_22203);
                        bool2 _17616 = any(bool2(_17612.x > 4.0f.xx.x, _17612.y > 4.0f.xx.y)).xx;
                        _22204 = float2(_17616.x ? 0.0f.xx.x : _22203.x, _17616.y ? 0.0f.xx.y : _22203.y);
                        break;
                    } while(false);
                    bool _17992 = all(bool2(_22187.x > 0.0f.xx.x, _22187.y > 0.0f.xx.y));
                    bool _17998;
                    if (_17992)
                    {
                        _17998 = all(bool2(_22187.x < 1.0f.xx.x, _22187.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17998 = _17992;
                    }
                    float _22216;
                    if (_17998)
                    {
                        _22216 = length(((_22187 + (_22204 * cbFI_Timestep)) - _5368) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22216 = 1000000000.0f;
                    }
                    uint _18025_dummy_parameter;
                    float _18049 = log(((r_depth_tm1.Load(int3(int2(floor(_17597 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18025_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _16562 = _22216 < 0.3499999940395355224609375f;
                    bool _16564 = _21004 < 0.3499999940395355224609375f;
                    bool _16574;
                    if (_16562)
                    {
                        _16574 = (!_16564) || (_18049 > _22237);
                    }
                    else
                    {
                        _16574 = _16562;
                    }
                    bool _16587;
                    if (!_16574)
                    {
                        _16587 = ((!_16562) && (!_16564)) && (_22216 < _21004);
                    }
                    else
                    {
                        _16587 = _16574;
                    }
                    _22792 = _16587 ? _18049 : _22237;
                    bool2 _22793 = _16587.xx;
                    _22794 = float2(_22793.x ? _22187.x : _21005.x, _22793.y ? _22187.y : _21005.y);
                    _22795 = _16587 ? _22216 : _21004;
                }
                float3 _18058 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _20983, 0.0f).xyz;
                float3 _18066 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21005, 0.0f).xyz;
                uint _18073_dummy_parameter;
                uint _18104_dummy_parameter;
                float _14592 = exp((_20982 * (-2.0f)) * (_20982 * 2.0f));
                float _14599 = exp((_21004 * (-2.0f)) * (_21004 * 2.0f));
                float _14612 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21005, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18104_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_20983, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18073_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14626 = ((_14592 * cbFI_Timestep) * ((1.0f - _14599) + ((_14599 * 2.0f) * _14612))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14636 = 1.0f - _14612;
                float _14643 = ((_14599 * _5593) * ((1.0f - _14592) + ((_14592 * 2.0f) * _14636))) + (9.9999997473787516355514526367188e-05f * _5593);
                float _14652 = (((_14592 * _14599) * 4.0f) * _14612) * _14636;
                _14670 = (_14652 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18066 - _18058, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14652)) * max(_14592, _14599));
                if (_6741 == 30u)
                {
                    _21006 = _18058;
                    break;
                }
                if (_6741 == 31u)
                {
                    _21006 = _18066;
                    break;
                }
                if (_6741 == 32u)
                {
                    _21006 = float3(_14592, _14599, _14612);
                    break;
                }
                _21006 = ((_18058 * _14626) + (_18066 * _14643)) / (_14626 + _14643).xxx;
                break;
            } while(false);
            _22166 = _14670;
            _22090 = _21006;
        }
        else
        {
            _22166 = 1.0f;
            _22090 = _22091;
        }
        uint _7071 = cbFI_pad0 & 255u;
        bool _21942;
        float3 _22089;
        if (_7071 != 0u)
        {
            float3 _7076 = r_present_backbuffer.Load(int3(_4869, 0)).xyz;
            float3 _7080 = r_current_interpolation_source.Load(int3(_4869, 0)).xyz;
            float3 _7084 = abs(_7076 - _7080);
            float3 _21007;
            if (_7071 == 2u)
            {
                _21007 = (abs(_7080) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21007 = 0.000244140625f.xxx;
            }
            bool _7100 = any(bool3(_7084.x > _21007.x, _7084.y > _21007.y, _7084.z > _21007.z));
            bool3 _22796 = _7100.xxx;
            _22089 = float3(_22796.x ? _7076.x : _22090.x, _22796.y ? _7076.y : _22090.y, _22796.z ? _7076.z : _22090.z);
            _21942 = _7100;
        }
        else
        {
            _22089 = _22090;
            _21942 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18142;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18142);
        }
        float3 _22071;
        if (_6741 == 1u)
        {
            _22071 = lerp(_8573, _8581, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22072;
            if (_6741 == 2u)
            {
                _22072 = lerp(_8589, _8597, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22073;
                if (_6741 == 3u)
                {
                    _22073 = float(_21942).xxx;
                }
                else
                {
                    float3 _22074;
                    if (_6741 == 4u)
                    {
                        _22074 = float3(((_19052 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22075;
                        if (_6741 == 5u)
                        {
                            _22075 = float3(((_7868 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22076;
                            if (_6741 == 6u)
                            {
                                _22076 = float3(_20558.xy, _20558.z + _20558.w);
                            }
                            else
                            {
                                float3 _22077;
                                if (_6741 == 7u)
                                {
                                    _22077 = r_current_interpolation_source.Load(int3(_4869, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22078;
                                    if (_6741 == 8u)
                                    {
                                        _22078 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5368, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22079;
                                        if (_6745)
                                        {
                                            uint _18164_dummy_parameter;
                                            uint _18196_dummy_parameter;
                                            _22079 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_5368 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18164_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_5368 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18196_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22080;
                                            if (_6748)
                                            {
                                                _22080 = _8589;
                                            }
                                            else
                                            {
                                                float3 _22081;
                                                if (_6741 == 20u)
                                                {
                                                    _22081 = _8573;
                                                }
                                                else
                                                {
                                                    float3 _22082;
                                                    if (_6741 == 21u)
                                                    {
                                                        _22082 = _8581;
                                                    }
                                                    else
                                                    {
                                                        float3 _22083;
                                                        if (_6741 == 22u)
                                                        {
                                                            _22083 = _8597;
                                                        }
                                                        else
                                                        {
                                                            float3 _22084;
                                                            if (_6741 == 18u)
                                                            {
                                                                _22084 = _21525;
                                                            }
                                                            else
                                                            {
                                                                float3 _22085;
                                                                if (_6741 == 19u)
                                                                {
                                                                    _22085 = _21267;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22086;
                                                                    if (_6741 == 23u)
                                                                    {
                                                                        _22086 = _21015;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22087;
                                                                        if (_6741 == 24u)
                                                                        {
                                                                            uint _7244 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7249 = float(rw_nfru_diagnostics.Load<uint>((_7244 + 35u) * 4 + 0));
                                                                            float _21008;
                                                                            if (_7249 > 0.0f)
                                                                            {
                                                                                _21008 = float(rw_nfru_diagnostics.Load<uint>((_7244 + 34u) * 4 + 0)) / _7249;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21008 = 0.0f;
                                                                            }
                                                                            _22087 = float3(float(rw_nfru_diagnostics.Load<uint>((_7244 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7244 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21008);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22087 = _22089;
                                                                        }
                                                                        _22086 = _22087;
                                                                    }
                                                                    _22085 = _22086;
                                                                }
                                                                _22084 = _22085;
                                                            }
                                                            _22083 = _22084;
                                                        }
                                                        _22082 = _22083;
                                                    }
                                                    _22081 = _22082;
                                                }
                                                _22080 = _22081;
                                            }
                                            _22079 = _22080;
                                        }
                                        _22078 = _22079;
                                    }
                                    _22077 = _22078;
                                }
                                _22076 = _22077;
                            }
                            _22075 = _22076;
                        }
                        _22074 = _22075;
                    }
                    _22073 = _22074;
                }
                _22072 = _22073;
            }
            _22071 = _22072;
        }
        float3 _22070;
        if ((_6741 >= 9u) && (_6741 <= 11u))
        {
            uint _7309 = 64u + uint((_19275.y * cbFI_MvDepthLaneSize.x) + _19275.x);
            uint _7313 = rw_nfru_diagnostics.Load<uint>(_7309 * 4 + 0) & 15u;
            float3 _22104;
            if (_6741 == 10u)
            {
                float3 _22069;
                if ((rw_nfru_diagnostics.Load<uint>(_7309 * 4 + 0) & 32u) != 0u)
                {
                    _22069 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22068;
                    if ((rw_nfru_diagnostics.Load<uint>(_7309 * 4 + 0) & 16u) != 0u)
                    {
                        _22068 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7334 = ((rw_nfru_diagnostics.Load<uint>(_7309 * 4 + 0) & 64u) != 0u).xxx;
                        _22068 = float3(_7334.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7334.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7334.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22069 = _22068;
                }
                _22104 = _22069;
            }
            else
            {
                float3 _22105;
                if (_6741 == 11u)
                {
                    uint _7347 = (rw_nfru_diagnostics.Load<uint>(_7309 * 4 + 0) >> 8u) & 15u;
                    uint _7350 = (rw_nfru_diagnostics.Load<uint>(_7309 * 4 + 0) >> 12u) & 15u;
                    float3 _22061;
                    if ((_7313 == 2u) || (_7313 == 3u))
                    {
                        _22061 = _4568[_7313];
                    }
                    else
                    {
                        bool _7362 = _7347 == 3u;
                        bool _7364 = _7350 == 3u;
                        float3 _22062;
                        if (_7362 && _7364)
                        {
                            _22062 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22063;
                            if (_7362)
                            {
                                _22063 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22064;
                                if (_7364)
                                {
                                    _22064 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22065;
                                    if ((_7347 == 4u) || (_7350 == 4u))
                                    {
                                        _22065 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22066;
                                        if ((_7347 == 1u) || (_7350 == 1u))
                                        {
                                            _22066 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _22798 = (_7313 == 1u).xxx;
                                            _22066 = float3(_22798.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _22798.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _22798.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22065 = _22066;
                                    }
                                    _22064 = _22065;
                                }
                                _22063 = _22064;
                            }
                            _22062 = _22063;
                        }
                        _22061 = _22062;
                    }
                    _22105 = _22061;
                }
                else
                {
                    _22105 = _4568[min(_7313, 7u)];
                }
                _22104 = _22105;
            }
            _22070 = _22104;
        }
        else
        {
            _22070 = _22071;
        }
        float4 _22108;
        if ((_6741 >= 14u) && (_6741 <= 16u))
        {
            float2 _22106;
            if (_6741 == 14u)
            {
                uint _7420_dummy_parameter;
                uint _7426_dummy_parameter;
                _22106 = r_flow_tm1.Load(int3(clamp(int2(floor(_5368 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7420_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7426_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22107;
                if (_6741 == 16u)
                {
                    uint _18272 = r_warped_flow_qdata_tm1.Load(int3(_5384, 0)).x & 2147483647u;
                    uint _18304 = uint(max((int((_18272 >> 16u) & 15u) - 6), 0));
                    _22107 = ((float2(float((1 - (2 * int((_18272 >> 15u) & 1u))) * int(((_18272 >> uint(7)) & 127u) << _18304)), float((1 - (2 * int((_18272 >> 14u) & 1u))) * int((_18272 & 127u) << _18304))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22107 = _7868 * float2(cbFI_DisplaySize);
                }
                _22106 = _22107;
            }
            uint2 _7459 = uint2(clamp(round(_22106 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7461 = _7459.x;
            uint _7468 = _7459.y;
            _22108 = float4(float(_7461 & 255u), float((_7461 >> 8u) | ((_7468 & 15u) << 4u)), float(_7468 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22109;
            if (_6741 == 17u)
            {
                _22109 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5384, 0)).x != 0u), _5828, 0.0f, 1.0f);
            }
            else
            {
                _22109 = float4(_22070, 1.0f);
            }
            _22108 = _22109;
        }
        rw_output[_4869] = _22108.xyz;
        if (_7051)
        {
            uint _18349 = uint((_4869.y * cbFI_DisplaySize.x) + _4869.x) * 2u;
            rw_nfru_select.Store<uint>(_18349 * 4 + 0, spvPackHalf2x16(_22108.xy));
            rw_nfru_select.Store<uint>((_18349 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22108.z, (_21942 || (_6741 != 0u)) ? 2.0f : _22166)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7526 = ((uint(_4869.y) * uint(cbFI_DisplaySize.x)) + uint(_4869.x)) * 6u;
            uint _18375 = spvPackHalf2x16(clamp(_8572.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7526 * 4 + 0, (((_18375 & 32767u) >> 4u) | ((((_18375 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8572.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18410 = spvPackHalf2x16(clamp(_8580.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7526 + 1u) * 4 + 0, (((_18410 & 32767u) >> 4u) | ((((_18410 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8580.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18445 = spvPackHalf2x16(clamp(_8588.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7526 + 2u) * 4 + 0, (((_18445 & 32767u) >> 4u) | ((((_18445 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8588.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18480 = spvPackHalf2x16(clamp(_8596.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7526 + 3u) * 4 + 0, (((_18480 & 32767u) >> 4u) | ((((_18480 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8596.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _18507 = r_current_interpolation_source.Load(int3(_4869, 0));
            uint _18521 = spvPackHalf2x16(clamp(_18507.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7526 + 4u) * 4 + 0, (((_18521 & 32767u) >> 4u) | ((((_18521 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_18507.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _22185;
            if (_21942 || (_6741 != 0u))
            {
                _22185 = 4294967295u;
            }
            else
            {
                uint _18556 = spvPackHalf2x16(clamp(_22108.xy, 0.0f.xx, 65000.0f.xx));
                _22185 = (((_18556 & 32767u) >> 4u) | ((((_18556 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22108.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7526 + 5u) * 4 + 0, _22185);
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
