static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19021;

static const int2 _1243[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1252[5] = { 2, 4, 7, 11, 16 };
static const float3 _4567[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4868 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4868.x >= cbFI_DisplaySize.x, _4868.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4868] = float4(r_present_backbuffer.Load(int3(_4868, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7721 = cbFI_DisplaySize - int2(1, 1);
                int2 _7722 = clamp(_4868, int2(0, 0), _7721);
                uint _7732 = uint((_7722.y * cbFI_DisplaySize.x) + _7722.x) * 2u;
                uint _7735 = rw_nfru_select.Load<uint>(_7732 * 4 + 0);
                float2 _7736 = spvUnpackHalf2x16(_7735);
                uint _7740 = rw_nfru_select.Load<uint>((_7732 + 1u) * 4 + 0);
                float2 _7741 = spvUnpackHalf2x16(_7740);
                float _7742 = _7736.x;
                float _7744 = _7741.x;
                if (_7741.y > 1.5f)
                {
                    rw_output[_4868] = float4(_7742, _7736.y, _7744, 1.0f).xyz;
                    break;
                }
                int _22350;
                float _22351;
                float3 _22352;
                float _22353;
                float _22354;
                _22354 = 0.0f;
                _22353 = 0.0f;
                _22352 = 0.0f.xxx;
                _22351 = 0.0f;
                _22350 = -2;
                float3 _22357;
                float _22358;
                float _22359;
                float _22360;
                for (; _22350 <= 2; _22354 = _22360, _22353 = _22359, _22352 = _22357, _22351 = _22358, _22350++)
                {
                    _22360 = _22354;
                    _22359 = _22353;
                    _22358 = _22351;
                    _22357 = _22352;
                    for (int _22355 = -2; _22355 <= 2; )
                    {
                        float _7638 = float((_22355 * _22355) + (_22350 * _22350));
                        float _7643 = exp(_7638 * (-0.319999992847442626953125f));
                        int2 _7648 = int2(_22355, _22350);
                        int2 _7758 = clamp(_4868 + (_7648 * int2(2, 2)), int2(0, 0), _7721);
                        uint _7768 = uint((_7758.y * cbFI_DisplaySize.x) + _7758.x) * 2u;
                        float _7665 = exp(_7638 * (-0.5f));
                        int2 _7790 = clamp(_4868 + (_7648 * int2(6, 6)), int2(0, 0), _7721);
                        _22360 += _7665;
                        _22359 += (_7665 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7790.y * cbFI_DisplaySize.x) + _7790.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _22358 += _7643;
                        _22357 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7768 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7768 + 1u) * 4 + 0)).x, _19021).xyz * _7643);
                        _22355++;
                        continue;
                    }
                }
                float3 _7695 = _22352 / _22351.xxx;
                rw_output[_4868] = float4(_7695 + ((float4(_7742, _7736.y, _7744, _7741.y).xyz - _7695) * clamp(_22353 / _22354, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5367 = (float2(_4868) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5369 = float2(cbFI_MvDepthLaneSize);
        int2 _5378 = int2(floor(_5367 * _5369));
        int2 _5383 = int2(floor(_5367 * float2(cbFI_FlowLaneSize)));
        float4 _7861 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5367 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7867 = r_warped_filled_flow_tm1.Load(int3(_5383, 0)).xy;
        float2 _7873 = r_warped_filled_motion_tp1.Load(int3(_5378, 0)).xy;
        bool _7895 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19022;
        if (_7895)
        {
            float _7908 = ((2.0f * _5367.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19022 = float2(atan(_7908) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5367.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7908 * _7908))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19022 = _5367;
        }
        bool _5404 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19043;
        bool _19185;
        int2 _19266;
        float3 _21516;
        if (_5404)
        {
            float _19024;
            float _19026;
            _19026 = 2.0f;
            _19024 = -1.0f;
            uint _4965[9];
            float _22361;
            float _22364;
            for (int _19023 = 0; _19023 < 9; _19026 = _22364, _19024 = _22361, _19023++)
            {
                _4965[_19023] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5378 + int2((_19023 % 3) - 1, (_19023 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4965[_19023] != 0u)
                {
                    float _22345;
                    if (_4965[_19023] == 0u)
                    {
                        _22345 = -1.0f;
                    }
                    else
                    {
                        _22345 = float((_4965[_19023] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _22364 = min(_19026, _22345);
                    _22361 = max(_19024, _22345);
                }
                else
                {
                    _22364 = _19026;
                    _22361 = _19024;
                }
            }
            float _5450 = float(_19024 >= 0.0f);
            float3 _18589 = 0.0f.xxx;
            _18589.y = _5450;
            float2 _19044;
            bool _19186;
            int2 _19267;
            float3 _21517;
            if ((_19024 - _19026) > 0.0199999995529651641845703125f)
            {
                float _19032;
                int2 _19033;
                float2 _19034;
                int2 _19036;
                float2 _19042;
                _19042 = _7873;
                _19036 = _5378;
                _19034 = _7873;
                _19033 = _5378;
                _19032 = -1.0f;
                float _22369;
                int2 _22373;
                float2 _22384;
                int2 _22395;
                float2 _22428;
                float _22745;
                int _19031 = 0;
                float _22326 = 1000000000.0f;
                for (; _19031 < 9; _22326 = _22745, _19042 = _22428, _19036 = _22395, _19034 = _22384, _19033 = _22373, _19032 = _22369, _19031++)
                {
                    if (_4965[_19031] == 0u)
                    {
                        _22745 = _22326;
                        _22428 = _19042;
                        _22395 = _19036;
                        _22384 = _19034;
                        _22373 = _19033;
                        _22369 = _19032;
                        continue;
                    }
                    int2 _5485 = clamp(_5378 + int2((_19031 % 3) - 1, (_19031 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _7983 = _4965[_19031] & 2147483647u;
                    uint _8015 = uint(max((int((_7983 >> 16u) & 15u) - 6), 0));
                    float2 _5491 = (float2(float((1 - (2 * int((_7983 >> 15u) & 1u))) * int(((_7983 >> uint(7)) & 127u) << _8015)), float((1 - (2 * int((_7983 >> 14u) & 1u))) * int((_7983 & 127u) << _8015))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _22312;
                    if (_4965[_19031] == 0u)
                    {
                        _22312 = -1.0f;
                    }
                    else
                    {
                        _22312 = float((_4965[_19031] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5496 = _22312 - 0.100000001490116119384765625f;
                    float2 _22313;
                    if (_7895)
                    {
                        float2 _8092 = clamp((((_19022 + (_5491 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8095 = tan(_8092.x);
                        _22313 = (float2(_8095 / cbFI_DeviceToViewDepth.z, (tan(_8092.y) * sqrt(1.0f + (_8095 * _8095))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _22313 = _19022 + (_5491 * cbFI_Timestep);
                    }
                    float _5503 = cbFI_Timestep - 1.0f;
                    float2 _22314;
                    if (_7895)
                    {
                        float2 _8163 = clamp((((_19022 + (_5491 * _5503)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8166 = tan(_8163.x);
                        _22314 = (float2(_8166 / cbFI_DeviceToViewDepth.z, (tan(_8163.y) * sqrt(1.0f + (_8166 * _8166))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _22314 = _19022 + (_5491 * _5503);
                    }
                    bool _8199 = all(bool2(_22313.x > 0.0f.xx.x, _22313.y > 0.0f.xx.y));
                    bool _8205;
                    if (_8199)
                    {
                        _8205 = all(bool2(_22313.x < 1.0f.xx.x, _22313.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8205 = _8199;
                    }
                    float _22317;
                    if (_8205)
                    {
                        uint _8212_dummy_parameter;
                        _22317 = max((_5496 - (log((r_depth_tm1.Load(int3(int2(floor(_22313 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8212_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _22317 = 0.0f;
                    }
                    bool _8242 = all(bool2(_22314.x > 0.0f.xx.x, _22314.y > 0.0f.xx.y));
                    bool _8248;
                    if (_8242)
                    {
                        _8248 = all(bool2(_22314.x < 1.0f.xx.x, _22314.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8248 = _8242;
                    }
                    float _22318;
                    if (_8248)
                    {
                        uint _8255_dummy_parameter;
                        _22318 = _22317 + max((_5496 - (log((r_depth_tp1.Load(int3(int2(floor(_22314 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8255_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _22318 = _22317;
                    }
                    float _22370;
                    int2 _22374;
                    float2 _22385;
                    int2 _22396;
                    float2 _22429;
                    float _22746;
                    if (_22318 == 0.0f)
                    {
                        bool _5538 = _5496 > _19032;
                        bool2 _22754 = _5538.xx;
                        _22746 = _22326;
                        _22429 = float2(_22754.x ? _5491.x : _19042.x, _22754.y ? _5491.y : _19042.y);
                        _22396 = int2(_22754.x ? _5485.x : _19036.x, _22754.y ? _5485.y : _19036.y);
                        _22385 = _19034;
                        _22374 = _19033;
                        _22370 = _5538 ? _5496 : _19032;
                    }
                    else
                    {
                        bool _5547 = _22318 < _22326;
                        bool2 _22750 = _5547.xx;
                        _22746 = _5547 ? _22318 : _22326;
                        _22429 = _19042;
                        _22396 = _19036;
                        _22385 = float2(_22750.x ? _5491.x : _19034.x, _22750.y ? _5491.y : _19034.y);
                        _22374 = int2(_22750.x ? _5485.x : _19033.x, _22750.y ? _5485.y : _19033.y);
                        _22370 = _19032;
                    }
                    _22745 = _22746;
                    _22428 = _22429;
                    _22395 = _22396;
                    _22384 = _22385;
                    _22373 = _22374;
                    _22369 = _22370;
                }
                bool _5559 = _19032 < 0.0f;
                bool2 _22760 = _5559.xx;
                int2 _22763 = int2(_22760.x ? _19033.x : _19036.x, _22760.y ? _19033.y : _19036.y);
                _21517 = float3(1.0f, _5450, float(any(bool2(_22763.x != _5378.x, _22763.y != _5378.y))));
                _19267 = _22763;
                _19186 = _5559 ? false : true;
                _19044 = float2(_22760.x ? _19034.x : _19042.x, _22760.y ? _19034.y : _19042.y);
            }
            else
            {
                _21517 = _18589;
                _19267 = _5378;
                _19186 = false;
                _19044 = _7873;
            }
            _21516 = _21517;
            _19266 = _19267;
            _19185 = _19186;
            _19043 = _19044;
        }
        else
        {
            _21516 = 0.0f.xxx;
            _19266 = _5378;
            _19185 = false;
            _19043 = _7873;
        }
        float2 _19045;
        if (_7895)
        {
            float2 _8320 = clamp((((_19022 + (_19043 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8323 = tan(_8320.x);
            _19045 = (float2(_8323 / cbFI_DeviceToViewDepth.z, (tan(_8320.y) * sqrt(1.0f + (_8323 * _8323))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19045 = _19022 + (_19043 * cbFI_Timestep);
        }
        float _5582 = cbFI_Timestep - 1.0f;
        float2 _19047;
        if (_7895)
        {
            float2 _8391 = clamp((((_19022 + (_19043 * _5582)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8394 = tan(_8391.x);
            _19047 = (float2(_8394 / cbFI_DeviceToViewDepth.z, (tan(_8391.y) * sqrt(1.0f + (_8394 * _8394))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19047 = _19022 + (_19043 * _5582);
        }
        float _5587 = -cbFI_Timestep;
        float2 _19048;
        if (_7895)
        {
            float2 _8462 = clamp((((_19022 + (_7867 * _5587)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8465 = tan(_8462.x);
            _19048 = (float2(_8465 / cbFI_DeviceToViewDepth.z, (tan(_8462.y) * sqrt(1.0f + (_8465 * _8465))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19048 = _19022 + (_7867 * _5587);
        }
        float _5592 = 1.0f - cbFI_Timestep;
        float2 _19049;
        if (_7895)
        {
            float2 _8533 = clamp((((_19022 + (_7867 * _5592)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8536 = tan(_8533.x);
            _19049 = (float2(_8536 / cbFI_DeviceToViewDepth.z, (tan(_8533.y) * sqrt(1.0f + (_8536 * _8536))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19049 = _19022 + (_7867 * _5592);
        }
        float4 _8571 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19045, 0.0f);
        float3 _8572 = _8571.xyz;
        float4 _8579 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19047, 0.0f);
        float3 _8580 = _8579.xyz;
        float4 _8587 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19048, 0.0f);
        float3 _8588 = _8587.xyz;
        float4 _8595 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19049, 0.0f);
        float3 _8596 = _8595.xyz;
        float4 _8610 = exp(_7861 - max(max(max(_7861.x, _7861.y), _7861.z), _7861.w).xxxx);
        float4 _8617 = _8610 / (dot(_8610, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5608 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19256;
        float _20564;
        if (_5608)
        {
            float2 _5614 = 0.5f.xx / _5369;
            float _5617 = _5614.x;
            float _5618 = -_5617;
            float _5620 = _5614.y;
            float _5621 = -_5620;
            float2 _5623 = _5367 + float2(_5618, _5621);
            float2 _5625 = float2(cbFI_DisplaySize);
            bool _19066;
            do
            {
                bool _8697 = all(bool2(_5623.x > 0.0f.xx.x, _5623.y > 0.0f.xx.y));
                bool _8703;
                if (_8697)
                {
                    _8703 = all(bool2(_5623.x < 1.0f.xx.x, _5623.y < 1.0f.xx.y));
                }
                else
                {
                    _8703 = _8697;
                }
                if (!_8703)
                {
                    _19066 = false;
                    break;
                }
                uint _8710_dummy_parameter;
                float4x4 _19064;
                do
                {
                    float4x4 _8724;
                    bool _19063;
                    do
                    {
                        _8724 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19063 = false;
                            break;
                        }
                        uint _8758 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8758 + 32u) * 4 + 0) != 1u)
                        {
                            _19063 = false;
                            break;
                        }
                        uint _19060;
                        _19060 = 0u;
                        for (; _19060 < 4u; _19060++)
                        {
                            for (uint _19061 = 0u; _19061 < 4u; )
                            {
                                _8724[_19060][_19061] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8758 + (_19060 * 4u)) + _19061) * 4 + 0));
                                _19061++;
                                continue;
                            }
                        }
                        _19063 = true;
                        break;
                    } while(false);
                    if (_19063)
                    {
                        _19064 = _8724;
                        break;
                    }
                    _19064 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19065;
                do
                {
                    float _8835 = _5623.x;
                    float _8838 = 1.0f - _5623.y;
                    float4 _8849 = mul(float4((float2(_8835, _8838) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5623 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8710_dummy_parameter))))), 0)).x, 1.0f), _19064);
                    float _8851 = _8849.w;
                    if (!(_8851 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19065 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8864 = ((_8849.xy / _8851.xx) + 1.0f.xx) * 0.5f;
                    _19065 = float2(_8864.x - _8835, _8838 - _8864.y);
                    break;
                } while(false);
                float2 _8661 = abs(_19065);
                if (any(bool2(_8661.x > 100000.0f.xx.x, _8661.y > 100000.0f.xx.y)))
                {
                    _19066 = false;
                    break;
                }
                float _8669 = length(_19065 * _5625);
                uint _8884_dummy_parameter;
                bool _8683 = _8669 > ((8.0f * _5625.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8690;
                if (_8683)
                {
                    _8690 = length((r_motion_tp1.Load(int3(int2(floor(_5623 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8884_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5625) < (0.20000000298023223876953125f * _8669);
                }
                else
                {
                    _8690 = _8683;
                }
                _19066 = _8690;
                break;
            } while(false);
            float2 _5635 = _5367 + float2(_5617, _5621);
            bool _19073;
            do
            {
                bool _8970 = all(bool2(_5635.x > 0.0f.xx.x, _5635.y > 0.0f.xx.y));
                bool _8976;
                if (_8970)
                {
                    _8976 = all(bool2(_5635.x < 1.0f.xx.x, _5635.y < 1.0f.xx.y));
                }
                else
                {
                    _8976 = _8970;
                }
                if (!_8976)
                {
                    _19073 = false;
                    break;
                }
                uint _8983_dummy_parameter;
                float4x4 _19071;
                do
                {
                    float4x4 _8997;
                    bool _19070;
                    do
                    {
                        _8997 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19070 = false;
                            break;
                        }
                        uint _9031 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9031 + 32u) * 4 + 0) != 1u)
                        {
                            _19070 = false;
                            break;
                        }
                        uint _19067;
                        _19067 = 0u;
                        for (; _19067 < 4u; _19067++)
                        {
                            for (uint _19068 = 0u; _19068 < 4u; )
                            {
                                _8997[_19067][_19068] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9031 + (_19067 * 4u)) + _19068) * 4 + 0));
                                _19068++;
                                continue;
                            }
                        }
                        _19070 = true;
                        break;
                    } while(false);
                    if (_19070)
                    {
                        _19071 = _8997;
                        break;
                    }
                    _19071 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19072;
                do
                {
                    float _9108 = _5635.x;
                    float _9111 = 1.0f - _5635.y;
                    float4 _9122 = mul(float4((float2(_9108, _9111) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5635 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8983_dummy_parameter))))), 0)).x, 1.0f), _19071);
                    float _9124 = _9122.w;
                    if (!(_9124 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19072 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9137 = ((_9122.xy / _9124.xx) + 1.0f.xx) * 0.5f;
                    _19072 = float2(_9137.x - _9108, _9111 - _9137.y);
                    break;
                } while(false);
                float2 _8934 = abs(_19072);
                if (any(bool2(_8934.x > 100000.0f.xx.x, _8934.y > 100000.0f.xx.y)))
                {
                    _19073 = false;
                    break;
                }
                float _8942 = length(_19072 * _5625);
                uint _9157_dummy_parameter;
                bool _8956 = _8942 > ((8.0f * _5625.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8963;
                if (_8956)
                {
                    _8963 = length((r_motion_tp1.Load(int3(int2(floor(_5635 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9157_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5625) < (0.20000000298023223876953125f * _8942);
                }
                else
                {
                    _8963 = _8956;
                }
                _19073 = _8963;
                break;
            } while(false);
            float2 _5648 = _5367 + float2(_5618, _5620);
            bool _19080;
            do
            {
                bool _9243 = all(bool2(_5648.x > 0.0f.xx.x, _5648.y > 0.0f.xx.y));
                bool _9249;
                if (_9243)
                {
                    _9249 = all(bool2(_5648.x < 1.0f.xx.x, _5648.y < 1.0f.xx.y));
                }
                else
                {
                    _9249 = _9243;
                }
                if (!_9249)
                {
                    _19080 = false;
                    break;
                }
                uint _9256_dummy_parameter;
                float4x4 _19078;
                do
                {
                    float4x4 _9270;
                    bool _19077;
                    do
                    {
                        _9270 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19077 = false;
                            break;
                        }
                        uint _9304 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9304 + 32u) * 4 + 0) != 1u)
                        {
                            _19077 = false;
                            break;
                        }
                        uint _19074;
                        _19074 = 0u;
                        for (; _19074 < 4u; _19074++)
                        {
                            for (uint _19075 = 0u; _19075 < 4u; )
                            {
                                _9270[_19074][_19075] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9304 + (_19074 * 4u)) + _19075) * 4 + 0));
                                _19075++;
                                continue;
                            }
                        }
                        _19077 = true;
                        break;
                    } while(false);
                    if (_19077)
                    {
                        _19078 = _9270;
                        break;
                    }
                    _19078 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19079;
                do
                {
                    float _9381 = _5648.x;
                    float _9384 = 1.0f - _5648.y;
                    float4 _9395 = mul(float4((float2(_9381, _9384) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5648 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9256_dummy_parameter))))), 0)).x, 1.0f), _19078);
                    float _9397 = _9395.w;
                    if (!(_9397 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19079 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9410 = ((_9395.xy / _9397.xx) + 1.0f.xx) * 0.5f;
                    _19079 = float2(_9410.x - _9381, _9384 - _9410.y);
                    break;
                } while(false);
                float2 _9207 = abs(_19079);
                if (any(bool2(_9207.x > 100000.0f.xx.x, _9207.y > 100000.0f.xx.y)))
                {
                    _19080 = false;
                    break;
                }
                float _9215 = length(_19079 * _5625);
                uint _9430_dummy_parameter;
                bool _9229 = _9215 > ((8.0f * _5625.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9236;
                if (_9229)
                {
                    _9236 = length((r_motion_tp1.Load(int3(int2(floor(_5648 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9430_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5625) < (0.20000000298023223876953125f * _9215);
                }
                else
                {
                    _9236 = _9229;
                }
                _19080 = _9236;
                break;
            } while(false);
            float2 _5660 = _5367 + _5614;
            bool _19087;
            do
            {
                bool _9516 = all(bool2(_5660.x > 0.0f.xx.x, _5660.y > 0.0f.xx.y));
                bool _9522;
                if (_9516)
                {
                    _9522 = all(bool2(_5660.x < 1.0f.xx.x, _5660.y < 1.0f.xx.y));
                }
                else
                {
                    _9522 = _9516;
                }
                if (!_9522)
                {
                    _19087 = false;
                    break;
                }
                uint _9529_dummy_parameter;
                float4x4 _19085;
                do
                {
                    float4x4 _9543;
                    bool _19084;
                    do
                    {
                        _9543 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19084 = false;
                            break;
                        }
                        uint _9577 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9577 + 32u) * 4 + 0) != 1u)
                        {
                            _19084 = false;
                            break;
                        }
                        uint _19081;
                        _19081 = 0u;
                        for (; _19081 < 4u; _19081++)
                        {
                            for (uint _19082 = 0u; _19082 < 4u; )
                            {
                                _9543[_19081][_19082] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9577 + (_19081 * 4u)) + _19082) * 4 + 0));
                                _19082++;
                                continue;
                            }
                        }
                        _19084 = true;
                        break;
                    } while(false);
                    if (_19084)
                    {
                        _19085 = _9543;
                        break;
                    }
                    _19085 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19086;
                do
                {
                    float _9654 = _5660.x;
                    float _9657 = 1.0f - _5660.y;
                    float4 _9668 = mul(float4((float2(_9654, _9657) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5660 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9529_dummy_parameter))))), 0)).x, 1.0f), _19085);
                    float _9670 = _9668.w;
                    if (!(_9670 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19086 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9683 = ((_9668.xy / _9670.xx) + 1.0f.xx) * 0.5f;
                    _19086 = float2(_9683.x - _9654, _9657 - _9683.y);
                    break;
                } while(false);
                float2 _9480 = abs(_19086);
                if (any(bool2(_9480.x > 100000.0f.xx.x, _9480.y > 100000.0f.xx.y)))
                {
                    _19087 = false;
                    break;
                }
                float _9488 = length(_19086 * _5625);
                uint _9703_dummy_parameter;
                bool _9502 = _9488 > ((8.0f * _5625.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9509;
                if (_9502)
                {
                    _9509 = length((r_motion_tp1.Load(int3(int2(floor(_5660 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9703_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5625) < (0.20000000298023223876953125f * _9488);
                }
                else
                {
                    _9509 = _9502;
                }
                _19087 = _9509;
                break;
            } while(false);
            float _5666 = 0.25f * (((float(_19066) + float(_19073)) + float(_19080)) + float(_19087));
            float4 _19257;
            if (_5666 < 1.0f)
            {
                bool _19094;
                do
                {
                    bool _9789 = all(bool2(_19045.x > 0.0f.xx.x, _19045.y > 0.0f.xx.y));
                    bool _9795;
                    if (_9789)
                    {
                        _9795 = all(bool2(_19045.x < 1.0f.xx.x, _19045.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9795 = _9789;
                    }
                    if (!_9795)
                    {
                        _19094 = false;
                        break;
                    }
                    uint _9802_dummy_parameter;
                    float4x4 _19092;
                    do
                    {
                        float4x4 _9816;
                        bool _19091;
                        do
                        {
                            _9816 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19091 = false;
                                break;
                            }
                            uint _9850 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9850 + 32u) * 4 + 0) != 1u)
                            {
                                _19091 = false;
                                break;
                            }
                            uint _19088;
                            _19088 = 0u;
                            for (; _19088 < 4u; _19088++)
                            {
                                for (uint _19089 = 0u; _19089 < 4u; )
                                {
                                    _9816[_19088][_19089] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9850 + (_19088 * 4u)) + _19089) * 4 + 0));
                                    _19089++;
                                    continue;
                                }
                            }
                            _19091 = true;
                            break;
                        } while(false);
                        if (_19091)
                        {
                            _19092 = _9816;
                            break;
                        }
                        _19092 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19093;
                    do
                    {
                        float _9930 = 1.0f - _19045.y;
                        float4 _9941 = mul(float4((float2(_19045.x, _9930) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19045 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9802_dummy_parameter))))), 0)).x, 1.0f), _19092);
                        float _9943 = _9941.w;
                        if (!(_9943 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19093 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9956 = ((_9941.xy / _9943.xx) + 1.0f.xx) * 0.5f;
                        _19093 = float2(_9956.x - _19045.x, _9930 - _9956.y);
                        break;
                    } while(false);
                    float2 _9753 = abs(_19093);
                    if (any(bool2(_9753.x > 100000.0f.xx.x, _9753.y > 100000.0f.xx.y)))
                    {
                        _19094 = false;
                        break;
                    }
                    float _9761 = length(_19093 * _5625);
                    uint _9976_dummy_parameter;
                    bool _9775 = _9761 > ((8.0f * _5625.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9782;
                    if (_9775)
                    {
                        _9782 = length((r_motion_tp1.Load(int3(int2(floor(_19045 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9976_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5625) < (0.20000000298023223876953125f * _9761);
                    }
                    else
                    {
                        _9782 = _9775;
                    }
                    _19094 = _9782;
                    break;
                } while(false);
                bool _19101;
                do
                {
                    bool _10062 = all(bool2(_19047.x > 0.0f.xx.x, _19047.y > 0.0f.xx.y));
                    bool _10068;
                    if (_10062)
                    {
                        _10068 = all(bool2(_19047.x < 1.0f.xx.x, _19047.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10068 = _10062;
                    }
                    if (!_10068)
                    {
                        _19101 = false;
                        break;
                    }
                    uint _10075_dummy_parameter;
                    float4x4 _19099;
                    do
                    {
                        float4x4 _10089;
                        bool _19098;
                        do
                        {
                            _10089 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19098 = false;
                                break;
                            }
                            uint _10123 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10123 + 32u) * 4 + 0) != 1u)
                            {
                                _19098 = false;
                                break;
                            }
                            uint _19095;
                            _19095 = 0u;
                            for (; _19095 < 4u; _19095++)
                            {
                                for (uint _19096 = 0u; _19096 < 4u; )
                                {
                                    _10089[_19095][_19096] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10123 + (_19095 * 4u)) + _19096) * 4 + 0));
                                    _19096++;
                                    continue;
                                }
                            }
                            _19098 = true;
                            break;
                        } while(false);
                        if (_19098)
                        {
                            _19099 = _10089;
                            break;
                        }
                        _19099 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19100;
                    do
                    {
                        float _10203 = 1.0f - _19047.y;
                        float4 _10214 = mul(float4((float2(_19047.x, _10203) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10075_dummy_parameter))))), 0)).x, 1.0f), _19099);
                        float _10216 = _10214.w;
                        if (!(_10216 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19100 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10229 = ((_10214.xy / _10216.xx) + 1.0f.xx) * 0.5f;
                        _19100 = float2(_10229.x - _19047.x, _10203 - _10229.y);
                        break;
                    } while(false);
                    float2 _10026 = abs(_19100);
                    if (any(bool2(_10026.x > 100000.0f.xx.x, _10026.y > 100000.0f.xx.y)))
                    {
                        _19101 = false;
                        break;
                    }
                    float _10034 = length(_19100 * _5625);
                    uint _10249_dummy_parameter;
                    bool _10048 = _10034 > ((8.0f * _5625.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10055;
                    if (_10048)
                    {
                        _10055 = length((r_motion_tp1.Load(int3(int2(floor(_19047 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10249_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5625) < (0.20000000298023223876953125f * _10034);
                    }
                    else
                    {
                        _10055 = _10048;
                    }
                    _19101 = _10055;
                    break;
                } while(false);
                bool _19108;
                do
                {
                    bool _10335 = all(bool2(_19048.x > 0.0f.xx.x, _19048.y > 0.0f.xx.y));
                    bool _10341;
                    if (_10335)
                    {
                        _10341 = all(bool2(_19048.x < 1.0f.xx.x, _19048.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10341 = _10335;
                    }
                    if (!_10341)
                    {
                        _19108 = false;
                        break;
                    }
                    uint _10348_dummy_parameter;
                    float4x4 _19106;
                    do
                    {
                        float4x4 _10362;
                        bool _19105;
                        do
                        {
                            _10362 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19105 = false;
                                break;
                            }
                            uint _10396 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10396 + 32u) * 4 + 0) != 1u)
                            {
                                _19105 = false;
                                break;
                            }
                            uint _19102;
                            _19102 = 0u;
                            for (; _19102 < 4u; _19102++)
                            {
                                for (uint _19103 = 0u; _19103 < 4u; )
                                {
                                    _10362[_19102][_19103] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10396 + (_19102 * 4u)) + _19103) * 4 + 0));
                                    _19103++;
                                    continue;
                                }
                            }
                            _19105 = true;
                            break;
                        } while(false);
                        if (_19105)
                        {
                            _19106 = _10362;
                            break;
                        }
                        _19106 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19107;
                    do
                    {
                        float _10476 = 1.0f - _19048.y;
                        float4 _10487 = mul(float4((float2(_19048.x, _10476) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19048 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10348_dummy_parameter))))), 0)).x, 1.0f), _19106);
                        float _10489 = _10487.w;
                        if (!(_10489 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19107 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10502 = ((_10487.xy / _10489.xx) + 1.0f.xx) * 0.5f;
                        _19107 = float2(_10502.x - _19048.x, _10476 - _10502.y);
                        break;
                    } while(false);
                    float2 _10299 = abs(_19107);
                    if (any(bool2(_10299.x > 100000.0f.xx.x, _10299.y > 100000.0f.xx.y)))
                    {
                        _19108 = false;
                        break;
                    }
                    float _10307 = length(_19107 * _5625);
                    uint _10522_dummy_parameter;
                    bool _10321 = _10307 > ((8.0f * _5625.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10328;
                    if (_10321)
                    {
                        _10328 = length((r_motion_tp1.Load(int3(int2(floor(_19048 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10522_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5625) < (0.20000000298023223876953125f * _10307);
                    }
                    else
                    {
                        _10328 = _10321;
                    }
                    _19108 = _10328;
                    break;
                } while(false);
                bool _19115;
                do
                {
                    bool _10608 = all(bool2(_19049.x > 0.0f.xx.x, _19049.y > 0.0f.xx.y));
                    bool _10614;
                    if (_10608)
                    {
                        _10614 = all(bool2(_19049.x < 1.0f.xx.x, _19049.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10614 = _10608;
                    }
                    if (!_10614)
                    {
                        _19115 = false;
                        break;
                    }
                    uint _10621_dummy_parameter;
                    float4x4 _19113;
                    do
                    {
                        float4x4 _10635;
                        bool _19112;
                        do
                        {
                            _10635 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19112 = false;
                                break;
                            }
                            uint _10669 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10669 + 32u) * 4 + 0) != 1u)
                            {
                                _19112 = false;
                                break;
                            }
                            uint _19109;
                            _19109 = 0u;
                            for (; _19109 < 4u; _19109++)
                            {
                                for (uint _19110 = 0u; _19110 < 4u; )
                                {
                                    _10635[_19109][_19110] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10669 + (_19109 * 4u)) + _19110) * 4 + 0));
                                    _19110++;
                                    continue;
                                }
                            }
                            _19112 = true;
                            break;
                        } while(false);
                        if (_19112)
                        {
                            _19113 = _10635;
                            break;
                        }
                        _19113 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19114;
                    do
                    {
                        float _10749 = 1.0f - _19049.y;
                        float4 _10760 = mul(float4((float2(_19049.x, _10749) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10621_dummy_parameter))))), 0)).x, 1.0f), _19113);
                        float _10762 = _10760.w;
                        if (!(_10762 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19114 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10775 = ((_10760.xy / _10762.xx) + 1.0f.xx) * 0.5f;
                        _19114 = float2(_10775.x - _19049.x, _10749 - _10775.y);
                        break;
                    } while(false);
                    float2 _10572 = abs(_19114);
                    if (any(bool2(_10572.x > 100000.0f.xx.x, _10572.y > 100000.0f.xx.y)))
                    {
                        _19115 = false;
                        break;
                    }
                    float _10580 = length(_19114 * _5625);
                    uint _10795_dummy_parameter;
                    bool _10594 = _10580 > ((8.0f * _5625.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10601;
                    if (_10594)
                    {
                        _10601 = length((r_motion_tp1.Load(int3(int2(floor(_19049 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10795_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5625) < (0.20000000298023223876953125f * _10580);
                    }
                    else
                    {
                        _10601 = _10594;
                    }
                    _19115 = _10601;
                    break;
                } while(false);
                float4 _5693 = _8617 * float4(_19094 ? 0.0f : 1.0f, _19101 ? 0.0f : 1.0f, _19108 ? 0.0f : 1.0f, _19115 ? 0.0f : 1.0f);
                float _5695 = dot(_5693, 1.0f.xxxx);
                float4 _19258;
                if (_5695 > 0.001000000047497451305389404296875f)
                {
                    _19258 = _5693 / _5695.xxxx;
                }
                else
                {
                    _19258 = _8617;
                }
                _19257 = _19258;
            }
            else
            {
                _19257 = _8617;
            }
            _20564 = _5666;
            _19256 = _19257;
        }
        else
        {
            _20564 = 0.0f;
            _19256 = _8617;
        }
        bool _5712 = _5404 && (!_19185);
        bool _5721;
        if (_5712)
        {
            _5721 = (_19256.z + _19256.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5721 = _5712;
        }
        bool _5732;
        if (_5721)
        {
            _5732 = length((_19048 - _19045) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5732 = _5721;
        }
        bool _19345;
        if (_5732)
        {
            uint4 _10824 = r_warped_motion_qdata_tp1.Load(int3(_19266, 0));
            uint _10825 = _10824.x;
            bool _19348;
            if (_10825 != 0u)
            {
                float _19334;
                if (_10825 == 0u)
                {
                    _19334 = -1.0f;
                }
                else
                {
                    _19334 = float((_10825 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5742 = _19334 - 0.12000000476837158203125f;
                bool _10844 = all(bool2(_19048.x > 0.0f.xx.x, _19048.y > 0.0f.xx.y));
                bool _10850;
                if (_10844)
                {
                    _10850 = all(bool2(_19048.x < 1.0f.xx.x, _19048.y < 1.0f.xx.y));
                }
                else
                {
                    _10850 = _10844;
                }
                bool _5752;
                if (_10850)
                {
                    uint _10857_dummy_parameter;
                    _5752 = (log((r_depth_tm1.Load(int3(int2(floor(_19048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10857_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5742;
                }
                else
                {
                    _5752 = _10850;
                }
                bool _5766;
                if (!_5752)
                {
                    bool _10887 = all(bool2(_19049.x > 0.0f.xx.x, _19049.y > 0.0f.xx.y));
                    bool _10893;
                    if (_10887)
                    {
                        _10893 = all(bool2(_19049.x < 1.0f.xx.x, _19049.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10893 = _10887;
                    }
                    bool _5764;
                    if (_10893)
                    {
                        uint _10900_dummy_parameter;
                        _5764 = (log((r_depth_tp1.Load(int3(int2(floor(_19049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10900_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5742;
                    }
                    else
                    {
                        _5764 = _10893;
                    }
                    _5766 = _5764;
                }
                else
                {
                    _5766 = _5752;
                }
                _19348 = _5766;
            }
            else
            {
                _19348 = false;
            }
            _19345 = _19348;
        }
        else
        {
            _19345 = false;
        }
        bool _5771 = _19185 || _19345;
        bool _5776;
        if (_5771)
        {
            bool _10930 = all(bool2(_19045.x > 0.0f.xx.x, _19045.y > 0.0f.xx.y));
            bool _10936;
            if (_10930)
            {
                _10936 = all(bool2(_19045.x < 1.0f.xx.x, _19045.y < 1.0f.xx.y));
            }
            else
            {
                _10936 = _10930;
            }
            _5776 = _10936;
        }
        else
        {
            _5776 = _5771;
        }
        bool _5781;
        if (_5776)
        {
            bool _10941 = all(bool2(_19047.x > 0.0f.xx.x, _19047.y > 0.0f.xx.y));
            bool _10947;
            if (_10941)
            {
                _10947 = all(bool2(_19047.x < 1.0f.xx.x, _19047.y < 1.0f.xx.y));
            }
            else
            {
                _10947 = _10941;
            }
            _5781 = _10947;
        }
        else
        {
            _5781 = _5776;
        }
        float4 _19468;
        if (_5781)
        {
            float _5787 = _19256.x + _19256.y;
            float _5792 = _19256.z + _19256.w;
            float _19363;
            if (_5787 > 0.001000000047497451305389404296875f)
            {
                _19363 = _19256.x / _5787;
            }
            else
            {
                _19363 = _5592;
            }
            _19468 = float4(_19256.x + (_5792 * _19363), _19256.y + (_5792 * (1.0f - _19363)), 0.0f, 0.0f);
        }
        else
        {
            _19468 = _19256;
        }
        bool _10975 = (cbFI_pad0 & 1024u) != 0u;
        bool _10951 = !_10975;
        bool _10952 = !_10951;
        bool _10969;
        if (_10952)
        {
            _10969 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19266.y * cbFI_MvDepthLaneSize.x) + _19266.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _10969 = _10951;
        }
        bool _11001;
        if (_10952)
        {
            _11001 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5383.y * cbFI_FlowLaneSize.x) + _5383.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11001 = _10951;
        }
        float _5827 = float(_11001);
        bool _19489;
        float4 _19528;
        float3 _21258;
        if (_10975)
        {
            bool _5837;
            if (_10969)
            {
                _5837 = all(bool2(_19045.x > 0.0f.xx.x, _19045.y > 0.0f.xx.y));
            }
            else
            {
                _5837 = _10969;
            }
            bool _5843;
            if (_5837)
            {
                _5843 = all(bool2(_19045.x < 1.0f.xx.x, _19045.y < 1.0f.xx.y));
            }
            else
            {
                _5843 = _5837;
            }
            bool _5850;
            if (_10969)
            {
                _5850 = all(bool2(_19047.x > 0.0f.xx.x, _19047.y > 0.0f.xx.y));
            }
            else
            {
                _5850 = _10969;
            }
            bool _5856;
            if (_5850)
            {
                _5856 = all(bool2(_19047.x < 1.0f.xx.x, _19047.y < 1.0f.xx.y));
            }
            else
            {
                _5856 = _5850;
            }
            bool _5863;
            if (_11001)
            {
                _5863 = all(bool2(_19048.x > 0.0f.xx.x, _19048.y > 0.0f.xx.y));
            }
            else
            {
                _5863 = _11001;
            }
            bool _5869;
            if (_5863)
            {
                _5869 = all(bool2(_19048.x < 1.0f.xx.x, _19048.y < 1.0f.xx.y));
            }
            else
            {
                _5869 = _5863;
            }
            bool _5876;
            if (_11001)
            {
                _5876 = all(bool2(_19049.x > 0.0f.xx.x, _19049.y > 0.0f.xx.y));
            }
            else
            {
                _5876 = _11001;
            }
            bool _5882;
            if (_5876)
            {
                _5882 = all(bool2(_19049.x < 1.0f.xx.x, _19049.y < 1.0f.xx.y));
            }
            else
            {
                _5882 = _5876;
            }
            bool _5884 = !_10969;
            if (_5884)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11043;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11043);
                }
            }
            bool _5889 = !_11001;
            if (_5889)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11053;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11053);
                }
            }
            if (_10969 && _5889)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11063;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11063);
                }
            }
            if (_5884 && _11001)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11073;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11073);
                }
            }
            float _5908 = float(_5843);
            float _5910 = float(_5856);
            bool _5913 = _5869 && _5882;
            float _19397;
            if (_5913)
            {
                _19397 = 1.0f;
            }
            else
            {
                _19397 = (_5869 || _5882) ? 0.5f : 0.0f;
            }
            bool _19412;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5843)) && (!_5856))
            {
                bool _5943;
                if (_5913)
                {
                    float _19405;
                    do
                    {
                        bool _11157 = all(bool2(_19048.x > 0.0f.xx.x, _19048.y > 0.0f.xx.y));
                        bool _11163;
                        if (_11157)
                        {
                            _11163 = all(bool2(_19048.x < 1.0f.xx.x, _19048.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11163 = _11157;
                        }
                        bool _11094 = !_11163;
                        bool _11101;
                        if (!_11094)
                        {
                            bool _11168 = all(bool2(_19049.x > 0.0f.xx.x, _19049.y > 0.0f.xx.y));
                            bool _11174;
                            if (_11168)
                            {
                                _11174 = all(bool2(_19049.x < 1.0f.xx.x, _19049.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11174 = _11168;
                            }
                            _11101 = !_11174;
                        }
                        else
                        {
                            _11101 = _11094;
                        }
                        if (_11101)
                        {
                            _19405 = 0.0f;
                            break;
                        }
                        uint _11181_dummy_parameter;
                        uint _11197_dummy_parameter;
                        float4x4 _19404;
                        do
                        {
                            float4x4 _11211;
                            bool _19403;
                            do
                            {
                                _11211 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _19403 = false;
                                    break;
                                }
                                uint _11245 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11245 + 32u) * 4 + 0) != 1u)
                                {
                                    _19403 = false;
                                    break;
                                }
                                uint _19400;
                                _19400 = 0u;
                                for (; _19400 < 4u; _19400++)
                                {
                                    for (uint _19401 = 0u; _19401 < 4u; )
                                    {
                                        _11211[_19400][_19401] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11245 + 16u) + (_19400 * 4u)) + _19401) * 4 + 0));
                                        _19401++;
                                        continue;
                                    }
                                }
                                _19403 = true;
                                break;
                            } while(false);
                            if (_19403)
                            {
                                _19404 = _11211;
                                break;
                            }
                            _19404 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11122 = mul(float4((float2(_19048.x, 1.0f - _19048.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11181_dummy_parameter))))), 0)).x, 1.0f), _19404);
                        float _11124 = _11122.w;
                        if (abs(_11124) < 9.9999999747524270787835121154785e-07f)
                        {
                            _19405 = 0.0f;
                            break;
                        }
                        float _11135 = abs(cbFI_DeviceToViewDepth.y / ((_11122.z / _11124) - cbFI_DeviceToViewDepth.x));
                        float _11138 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11197_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _19405 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11135 - _11138) / max(max(_11135, _11138), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5943 = _19405 >= 0.5f;
                }
                else
                {
                    _5943 = _5913;
                }
                bool _5951;
                if (_5943)
                {
                    _5951 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5951 = _5943;
                }
                bool _19413;
                if (_5951)
                {
                    uint _11349_dummy_parameter;
                    float4x4 _19410;
                    do
                    {
                        float4x4 _11363;
                        bool _19409;
                        do
                        {
                            _11363 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19409 = false;
                                break;
                            }
                            uint _11397 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11397 + 32u) * 4 + 0) != 1u)
                            {
                                _19409 = false;
                                break;
                            }
                            uint _19406;
                            _19406 = 0u;
                            for (; _19406 < 4u; _19406++)
                            {
                                for (uint _19407 = 0u; _19407 < 4u; )
                                {
                                    _11363[_19406][_19407] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11397 + 16u) + (_19406 * 4u)) + _19407) * 4 + 0));
                                    _19407++;
                                    continue;
                                }
                            }
                            _19409 = true;
                            break;
                        } while(false);
                        if (_19409)
                        {
                            _19410 = _11363;
                            break;
                        }
                        _19410 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _19411;
                    do
                    {
                        float _11477 = 1.0f - _19048.y;
                        float4 _11488 = mul(float4((float2(_19048.x, _11477) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11349_dummy_parameter))))), 0)).x, 1.0f), _19410);
                        float _11490 = _11488.w;
                        if (!(_11490 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19411 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11503 = ((_11488.xy / _11490.xx) + 1.0f.xx) * 0.5f;
                        _19411 = float2(_11503.x - _19048.x, _11477 - _11503.y);
                        break;
                    } while(false);
                    float2 _5964 = float2(cbFI_DisplaySize);
                    _19413 = length(((_19048 + _19411) - _19049) * _5964) <= ((0.100000001490116119384765625f * length(_19411 * _5964)) + 8.0f);
                }
                else
                {
                    _19413 = _5943;
                }
                _19412 = _19413;
            }
            else
            {
                _19412 = true;
            }
            bool _5978 = !_19412;
            bool _22764 = _5978 ? false : _5882;
            bool _22765 = _5978 ? false : _5869;
            bool _19490;
            float4 _19529;
            if (!(((_5843 && _5856) && _22765) && _22764))
            {
                float4 _6000 = _19468 * float4(_5908, _5910, float(_22765), float(_22764));
                float _6002 = dot(_6000, 1.0f.xxxx);
                bool _6005 = !(_6002 > 0.0f);
                float4 _19530;
                if (!_6005)
                {
                    _19530 = _6000 / _6002.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11525;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11525);
                    }
                    _19530 = 0.0f.xxxx;
                }
                _19529 = _19530;
                _19490 = _6005;
            }
            else
            {
                _19529 = _19468;
                _19490 = false;
            }
            _21258 = float3(_5908, _5910, _19397);
            _19528 = _19529;
            _19489 = _19490;
        }
        else
        {
            _21258 = float3(float(_10969), _5827, 0.0f);
            _19528 = _19468;
            _19489 = false;
        }
        bool _6023 = !_19489;
        float4 _19621;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6023)
        {
            float _6030 = _19528.x + _19528.y;
            float4 _19622;
            if (_6030 > 0.001000000047497451305389404296875f)
            {
                _19622 = float4(_19528.x / _6030, _19528.y / _6030, 0.0f, 0.0f);
            }
            else
            {
                _19622 = float4(_5592, cbFI_Timestep, 0.0f, 0.0f);
            }
            _19621 = _19622;
        }
        else
        {
            _19621 = _19528;
        }
        float4 _19798;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6023) && _10969)
        {
            float _19595;
            do
            {
                uint4 _11665 = r_warped_motion_qdata_tp1.Load(int3(_19266, 0));
                uint _11666 = _11665.x;
                if (_11666 != 0u)
                {
                    float _19594;
                    if (_11666 == 0u)
                    {
                        _19594 = -1.0f;
                    }
                    else
                    {
                        _19594 = float((_11666 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19595 = _19594;
                    break;
                }
                int _19577;
                uint _19578;
                _19578 = _11666;
                _19577 = -1;
                uint _19593;
                for (; _19577 <= 1; _19578 = _19593, _19577++)
                {
                    _19593 = _19578;
                    for (int _19591 = -1; _19591 <= 1; )
                    {
                        _19593 = max(_19593, r_warped_motion_qdata_tp1.Load(int3(clamp(_19266 + int2(_19591, _19577), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _19591++;
                        continue;
                    }
                }
                if (_19578 != 0u)
                {
                    float _19590;
                    if (_19578 == 0u)
                    {
                        _19590 = -1.0f;
                    }
                    else
                    {
                        _19590 = float((_19578 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19595 = _19590;
                    break;
                }
                uint _19580;
                _19580 = 4294967295u;
                uint _22465;
                for (int _19579 = 0; _19579 < 8; _19580 = _22465, _19579++)
                {
                    int _19583 = 0;
                    for (;;)
                    {
                        if (_19583 < 5)
                        {
                            int2 _11616 = _19266 + (_1243[_19579] * _1252[_19583].xx);
                            bool _11619 = any(bool2(_11616.x < int2(0, 0).x, _11616.y < int2(0, 0).y));
                            bool _11627;
                            if (!_11619)
                            {
                                _11627 = any(bool2(_11616.x >= cbFI_MvDepthLaneSize.x, _11616.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11627 = _11619;
                            }
                            if (_11627)
                            {
                                _22465 = _19580;
                                break;
                            }
                            uint4 _11705 = r_warped_motion_qdata_tp1.Load(int3(_11616, 0));
                            uint _11706 = _11705.x;
                            if (_11706 != 0u)
                            {
                                _22465 = min(_19580, _11706);
                                break;
                            }
                            _19583++;
                            continue;
                        }
                        else
                        {
                            _22465 = _19580;
                            break;
                        }
                    }
                }
                float _19582;
                if (_19580 == 4294967295u)
                {
                    _19582 = -1.0f;
                }
                else
                {
                    float _19581;
                    if (_19580 == 0u)
                    {
                        _19581 = -1.0f;
                    }
                    else
                    {
                        _19581 = float((_19580 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19582 = _19581;
                }
                _19595 = _19582;
                break;
            } while(false);
            float _6066 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6069 = r_warped_motion_qdata_tp1.Load(int3(_19266, 0)).x == 0u;
            bool _6075;
            if (_6069)
            {
                bool _11731 = all(bool2(_19045.x > 0.0f.xx.x, _19045.y > 0.0f.xx.y));
                bool _11737;
                if (_11731)
                {
                    _11737 = all(bool2(_19045.x < 1.0f.xx.x, _19045.y < 1.0f.xx.y));
                }
                else
                {
                    _11737 = _11731;
                }
                _6075 = _11737;
            }
            else
            {
                _6075 = _6069;
            }
            bool _6080;
            if (_6075)
            {
                bool _11742 = all(bool2(_19047.x > 0.0f.xx.x, _19047.y > 0.0f.xx.y));
                bool _11748;
                if (_11742)
                {
                    _11748 = all(bool2(_19047.x < 1.0f.xx.x, _19047.y < 1.0f.xx.y));
                }
                else
                {
                    _11748 = _11742;
                }
                _6080 = _11748;
            }
            else
            {
                _6080 = _6075;
            }
            bool _19607;
            float4 _19616;
            if (_6080)
            {
                uint _11755_dummy_parameter;
                float _11779 = log((r_depth_tm1.Load(int3(int2(floor(_19045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11755_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _11787_dummy_parameter;
                float _11811 = log((r_depth_tp1.Load(int3(int2(floor(_19047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11787_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _6091 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6098;
                if (_6091)
                {
                    _6098 = _11811 > (_11779 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6098 = _6091;
                }
                bool _19612;
                float4 _19634;
                if (_6098)
                {
                    _19634 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _19612 = true;
                }
                else
                {
                    bool _6104 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6111;
                    if (_6104)
                    {
                        _6111 = _11779 > (_11811 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6111 = _6104;
                    }
                    bool4 _22766 = _6111.xxxx;
                    _19634 = float4(_22766.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _19621.x, _22766.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _19621.y, _22766.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _19621.z, _22766.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _19621.w);
                    _19612 = _6111 ? true : false;
                }
                _19616 = _19634;
                _19607 = _19612;
            }
            else
            {
                _19616 = _19621;
                _19607 = false;
            }
            float4 _19689;
            if (_19607)
            {
                _19689 = 1.0f.xxxx;
            }
            else
            {
                bool _6122 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6128;
                if (_6122)
                {
                    _6128 = _19616.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6128 = _6122;
                }
                bool _6133;
                if (_6128)
                {
                    bool _11817 = all(bool2(_19047.x > 0.0f.xx.x, _19047.y > 0.0f.xx.y));
                    bool _11823;
                    if (_11817)
                    {
                        _11823 = all(bool2(_19047.x < 1.0f.xx.x, _19047.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11823 = _11817;
                    }
                    _6133 = _11823;
                }
                else
                {
                    _6133 = _6128;
                }
                float4 _19690;
                if (_6133)
                {
                    float _19643;
                    if (_19595 >= 0.0f)
                    {
                        _19643 = _19595 - _6066;
                    }
                    else
                    {
                        float _19639;
                        _19639 = 2.0f;
                        float _11880;
                        for (int _19638 = 0; _19638 < 24; _19639 = _11880, _19638++)
                        {
                            float _11844 = float(_19638 & 7) * 0.785398185253143310546875f;
                            int _11846 = _19638 >> 3;
                            int _19640;
                            if (_11846 == 0)
                            {
                                _19640 = 16;
                            }
                            else
                            {
                                _19640 = (_11846 == 1) ? 48 : 96;
                            }
                            uint _11912_dummy_parameter;
                            _11880 = min(_19639, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19047 + ((cbFI_MvDepthLaneSizeRcp * float(_19640)) * float2(cos(_11844), sin(_11844))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11912_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _19643 = _19639;
                    }
                    uint _11944_dummy_parameter;
                    float4 _19691;
                    if (r_depth_tp1.Load(int3(int2(floor(_19047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11944_dummy_parameter))))), 0)).x > ((exp((_19643 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _19691 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _19691 = 1.0f.xxxx;
                    }
                    _19690 = _19691;
                }
                else
                {
                    _19690 = 1.0f.xxxx;
                }
                _19689 = _19690;
            }
            bool _6161 = _19595 >= 0.0f;
            bool _6162 = (!_19607) && _6161;
            bool _6169;
            if (_6162)
            {
                _6169 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6169 = _6162;
            }
            bool _6175;
            if (_6169)
            {
                _6175 = _19616.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6175 = _6169;
            }
            bool _6180;
            if (_6175)
            {
                bool _11968 = all(bool2(_19045.x > 0.0f.xx.x, _19045.y > 0.0f.xx.y));
                bool _11974;
                if (_11968)
                {
                    _11974 = all(bool2(_19045.x < 1.0f.xx.x, _19045.y < 1.0f.xx.y));
                }
                else
                {
                    _11974 = _11968;
                }
                _6180 = _11974;
            }
            else
            {
                _6180 = _6175;
            }
            float4 _19714;
            if (_6180)
            {
                float _19683;
                if (_6161)
                {
                    _19683 = _19595 - _6066;
                }
                else
                {
                    float _19679;
                    _19679 = 2.0f;
                    float _12031;
                    for (int _19678 = 0; _19678 < 24; _19679 = _12031, _19678++)
                    {
                        float _11995 = float(_19678 & 7) * 0.785398185253143310546875f;
                        int _11997 = _19678 >> 3;
                        int _19680;
                        if (_11997 == 0)
                        {
                            _19680 = 16;
                        }
                        else
                        {
                            _19680 = (_11997 == 1) ? 48 : 96;
                        }
                        uint _12047_dummy_parameter;
                        _12031 = min(_19679, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19045 + ((cbFI_MvDepthLaneSizeRcp * float(_19680)) * float2(cos(_11995), sin(_11995))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12047_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _19683 = _19679;
                }
                uint _12095_dummy_parameter;
                float4 _19715;
                if (r_depth_tm1.Load(int3(int2(floor(_19045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12095_dummy_parameter))))), 0)).x > ((exp((_19683 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _18741 = _19689;
                    _18741.x = 0.0f;
                    _19715 = _18741;
                }
                else
                {
                    _19715 = _19689;
                }
                _19714 = _19715;
            }
            else
            {
                _19714 = _19689;
            }
            float4 _19727;
            if (_6162)
            {
                float _12121 = (exp(((_19595 - _6066) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6218 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6224;
                if (_6218)
                {
                    _6224 = _19616.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6224 = _6218;
                }
                bool _6229;
                if (_6224)
                {
                    bool _12126 = all(bool2(_19049.x > 0.0f.xx.x, _19049.y > 0.0f.xx.y));
                    bool _12132;
                    if (_12126)
                    {
                        _12132 = all(bool2(_19049.x < 1.0f.xx.x, _19049.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12132 = _12126;
                    }
                    _6229 = _12132;
                }
                else
                {
                    _6229 = _6224;
                }
                bool _6237;
                if (_6229)
                {
                    uint _12139_dummy_parameter;
                    _6237 = r_depth_tp1.Load(int3(int2(floor(_19049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12139_dummy_parameter))))), 0)).x > _12121;
                }
                else
                {
                    _6237 = _6229;
                }
                float4 _19725;
                if (_6237)
                {
                    float4 _18744 = _19714;
                    _18744.w = 0.0f;
                    _19725 = _18744;
                }
                else
                {
                    _19725 = _19714;
                }
                bool _6244 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6250;
                if (_6244)
                {
                    _6250 = _19616.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6250 = _6244;
                }
                bool _6255;
                if (_6250)
                {
                    bool _12156 = all(bool2(_19048.x > 0.0f.xx.x, _19048.y > 0.0f.xx.y));
                    bool _12162;
                    if (_12156)
                    {
                        _12162 = all(bool2(_19048.x < 1.0f.xx.x, _19048.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12162 = _12156;
                    }
                    _6255 = _12162;
                }
                else
                {
                    _6255 = _6250;
                }
                bool _6263;
                if (_6255)
                {
                    uint _12169_dummy_parameter;
                    _6263 = r_depth_tm1.Load(int3(int2(floor(_19048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12169_dummy_parameter))))), 0)).x > _12121;
                }
                else
                {
                    _6263 = _6255;
                }
                float4 _19728;
                if (_6263)
                {
                    float4 _18747 = _19725;
                    _18747.z = 0.0f;
                    _19728 = _18747;
                }
                else
                {
                    _19728 = _19725;
                }
                _19727 = _19728;
            }
            else
            {
                _19727 = _19714;
            }
            float4 _19799;
            if (any(bool4(_19727.x < 1.0f.xxxx.x, _19727.y < 1.0f.xxxx.y, _19727.z < 1.0f.xxxx.z, _19727.w < 1.0f.xxxx.w)))
            {
                float4 _6274 = _19616 * _19727;
                float _6276 = dot(_6274, 1.0f.xxxx);
                float4 _19800;
                if (_6276 > 0.0f)
                {
                    _19800 = _6274 / _6276.xxxx;
                }
                else
                {
                    bool _6287 = _19727.y == 0.0f;
                    bool _6293;
                    if (_6287)
                    {
                        _6293 = _19727.x > 0.0f;
                    }
                    else
                    {
                        _6293 = _6287;
                    }
                    bool _6298;
                    if (_6293)
                    {
                        bool _12186 = all(bool2(_19045.x > 0.0f.xx.x, _19045.y > 0.0f.xx.y));
                        bool _12192;
                        if (_12186)
                        {
                            _12192 = all(bool2(_19045.x < 1.0f.xx.x, _19045.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12192 = _12186;
                        }
                        _6298 = _12192;
                    }
                    else
                    {
                        _6298 = _6293;
                    }
                    float4 _19801;
                    if (_6298)
                    {
                        _19801 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6303 = _19727.x == 0.0f;
                        bool _6309;
                        if (_6303)
                        {
                            _6309 = _19727.y > 0.0f;
                        }
                        else
                        {
                            _6309 = _6303;
                        }
                        bool _6314;
                        if (_6309)
                        {
                            bool _12197 = all(bool2(_19047.x > 0.0f.xx.x, _19047.y > 0.0f.xx.y));
                            bool _12203;
                            if (_12197)
                            {
                                _12203 = all(bool2(_19047.x < 1.0f.xx.x, _19047.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12203 = _12197;
                            }
                            _6314 = _12203;
                        }
                        else
                        {
                            _6314 = _6309;
                        }
                        bool4 _22769 = _6314.xxxx;
                        _19801 = float4(_22769.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _19616.x, _22769.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _19616.y, _22769.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _19616.z, _22769.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _19616.w);
                    }
                    _19800 = _19801;
                }
                _19799 = _19800;
            }
            else
            {
                _19799 = _19616;
            }
            _19798 = _19799;
        }
        else
        {
            _19798 = _19621;
        }
        float4 _20528;
        bool _20834;
        float3 _21006;
        if (((cbFI_pad0 & 32768u) != 0u) && _6023)
        {
            bool _6331 = _19798.x > 0.00999999977648258209228515625f;
            bool _6334 = _19798.y > 0.00999999977648258209228515625f;
            bool _6343 = (_19798.z + _19798.w) > 0.0199999995529651641845703125f;
            bool _6349;
            if (_6343)
            {
                bool _12208 = all(bool2(_19048.x > 0.0f.xx.x, _19048.y > 0.0f.xx.y));
                bool _12214;
                if (_12208)
                {
                    _12214 = all(bool2(_19048.x < 1.0f.xx.x, _19048.y < 1.0f.xx.y));
                }
                else
                {
                    _12214 = _12208;
                }
                _6349 = _12214;
            }
            else
            {
                _6349 = _6343;
            }
            bool _6354;
            if (_6349)
            {
                bool _12219 = all(bool2(_19049.x > 0.0f.xx.x, _19049.y > 0.0f.xx.y));
                bool _12225;
                if (_12219)
                {
                    _12225 = all(bool2(_19049.x < 1.0f.xx.x, _19049.y < 1.0f.xx.y));
                }
                else
                {
                    _12225 = _12219;
                }
                _6354 = _12225;
            }
            else
            {
                _6354 = _6349;
            }
            bool _6361;
            if (_6354)
            {
                float _19814;
                do
                {
                    bool _12308 = all(bool2(_19048.x > 0.0f.xx.x, _19048.y > 0.0f.xx.y));
                    bool _12314;
                    if (_12308)
                    {
                        _12314 = all(bool2(_19048.x < 1.0f.xx.x, _19048.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12314 = _12308;
                    }
                    bool _12245 = !_12314;
                    bool _12252;
                    if (!_12245)
                    {
                        bool _12319 = all(bool2(_19049.x > 0.0f.xx.x, _19049.y > 0.0f.xx.y));
                        bool _12325;
                        if (_12319)
                        {
                            _12325 = all(bool2(_19049.x < 1.0f.xx.x, _19049.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12325 = _12319;
                        }
                        _12252 = !_12325;
                    }
                    else
                    {
                        _12252 = _12245;
                    }
                    if (_12252)
                    {
                        _19814 = 0.0f;
                        break;
                    }
                    uint _12332_dummy_parameter;
                    uint _12348_dummy_parameter;
                    float4x4 _19813;
                    do
                    {
                        float4x4 _12362;
                        bool _19812;
                        do
                        {
                            _12362 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19812 = false;
                                break;
                            }
                            uint _12396 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12396 + 32u) * 4 + 0) != 1u)
                            {
                                _19812 = false;
                                break;
                            }
                            uint _19809;
                            _19809 = 0u;
                            for (; _19809 < 4u; _19809++)
                            {
                                for (uint _19810 = 0u; _19810 < 4u; )
                                {
                                    _12362[_19809][_19810] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12396 + 16u) + (_19809 * 4u)) + _19810) * 4 + 0));
                                    _19810++;
                                    continue;
                                }
                            }
                            _19812 = true;
                            break;
                        } while(false);
                        if (_19812)
                        {
                            _19813 = _12362;
                            break;
                        }
                        _19813 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12273 = mul(float4((float2(_19048.x, 1.0f - _19048.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12332_dummy_parameter))))), 0)).x, 1.0f), _19813);
                    float _12275 = _12273.w;
                    if (abs(_12275) < 9.9999999747524270787835121154785e-07f)
                    {
                        _19814 = 0.0f;
                        break;
                    }
                    float _12286 = abs(cbFI_DeviceToViewDepth.y / ((_12273.z / _12275) - cbFI_DeviceToViewDepth.x));
                    float _12289 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12348_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _19814 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12286 - _12289) / max(max(_12286, _12289), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6361 = _19814 < 0.5f;
            }
            else
            {
                _6361 = _6354;
            }
            float4 _19833;
            if (_6361)
            {
                uint _12500_dummy_parameter;
                uint _12531_dummy_parameter;
                float4 _19834;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12500_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12531_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _19834 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _19834 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _19833 = _19834;
            }
            else
            {
                _19833 = 1.0f.xxxx;
            }
            bool _6385;
            if (_10969)
            {
                bool _12560 = all(bool2(_19045.x > 0.0f.xx.x, _19045.y > 0.0f.xx.y));
                bool _12566;
                if (_12560)
                {
                    _12566 = all(bool2(_19045.x < 1.0f.xx.x, _19045.y < 1.0f.xx.y));
                }
                else
                {
                    _12566 = _12560;
                }
                _6385 = _12566;
            }
            else
            {
                _6385 = _10969;
            }
            bool _6391;
            if (_10969)
            {
                bool _12571 = all(bool2(_19047.x > 0.0f.xx.x, _19047.y > 0.0f.xx.y));
                bool _12577;
                if (_12571)
                {
                    _12577 = all(bool2(_19047.x < 1.0f.xx.x, _19047.y < 1.0f.xx.y));
                }
                else
                {
                    _12577 = _12571;
                }
                _6391 = _12577;
            }
            else
            {
                _6391 = _10969;
            }
            bool _6397;
            if (_11001)
            {
                bool _12582 = all(bool2(_19048.x > 0.0f.xx.x, _19048.y > 0.0f.xx.y));
                bool _12588;
                if (_12582)
                {
                    _12588 = all(bool2(_19048.x < 1.0f.xx.x, _19048.y < 1.0f.xx.y));
                }
                else
                {
                    _12588 = _12582;
                }
                _6397 = _12588;
            }
            else
            {
                _6397 = _11001;
            }
            bool _6403;
            if (_11001)
            {
                bool _12593 = all(bool2(_19049.x > 0.0f.xx.x, _19049.y > 0.0f.xx.y));
                bool _12599;
                if (_12593)
                {
                    _12599 = all(bool2(_19049.x < 1.0f.xx.x, _19049.y < 1.0f.xx.y));
                }
                else
                {
                    _12599 = _12593;
                }
                _6403 = _12599;
            }
            else
            {
                _6403 = _11001;
            }
            bool _6406 = _6397 != _6403;
            bool _6412;
            if (_6406)
            {
                _6412 = _6385 || _6391;
            }
            else
            {
                _6412 = _6406;
            }
            float4 _19936;
            if (_6412)
            {
                float4 _18774 = _19833;
                _18774.z = 0.0f;
                _18774.w = 0.0f;
                _19936 = _18774;
            }
            else
            {
                _19936 = _19833;
            }
            bool _6419 = _6385 && _6331;
            bool _6422 = _6391 && _6334;
            float4 _20041;
            float3 _21115;
            if (_6419 || _6422)
            {
                float _19931;
                do
                {
                    uint4 _12738 = r_warped_motion_qdata_tp1.Load(int3(_19266, 0));
                    uint _12739 = _12738.x;
                    if (_12739 != 0u)
                    {
                        float _19930;
                        if (_12739 == 0u)
                        {
                            _19930 = -1.0f;
                        }
                        else
                        {
                            _19930 = float((_12739 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _19931 = _19930;
                        break;
                    }
                    int _19913;
                    uint _19914;
                    _19914 = _12739;
                    _19913 = -1;
                    uint _19929;
                    for (; _19913 <= 1; _19914 = _19929, _19913++)
                    {
                        _19929 = _19914;
                        for (int _19927 = -1; _19927 <= 1; )
                        {
                            _19929 = max(_19929, r_warped_motion_qdata_tp1.Load(int3(clamp(_19266 + int2(_19927, _19913), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _19927++;
                            continue;
                        }
                    }
                    if (_19914 != 0u)
                    {
                        float _19926;
                        if (_19914 == 0u)
                        {
                            _19926 = -1.0f;
                        }
                        else
                        {
                            _19926 = float((_19914 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _19931 = _19926;
                        break;
                    }
                    uint _19916;
                    _19916 = 4294967295u;
                    uint _22466;
                    for (int _19915 = 0; _19915 < 8; _19916 = _22466, _19915++)
                    {
                        int _19919 = 0;
                        for (;;)
                        {
                            if (_19919 < 5)
                            {
                                int2 _12689 = _19266 + (_1243[_19915] * _1252[_19919].xx);
                                bool _12692 = any(bool2(_12689.x < int2(0, 0).x, _12689.y < int2(0, 0).y));
                                bool _12700;
                                if (!_12692)
                                {
                                    _12700 = any(bool2(_12689.x >= cbFI_MvDepthLaneSize.x, _12689.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12700 = _12692;
                                }
                                if (_12700)
                                {
                                    _22466 = _19916;
                                    break;
                                }
                                uint4 _12778 = r_warped_motion_qdata_tp1.Load(int3(_12689, 0));
                                uint _12779 = _12778.x;
                                if (_12779 != 0u)
                                {
                                    _22466 = min(_19916, _12779);
                                    break;
                                }
                                _19919++;
                                continue;
                            }
                            else
                            {
                                _22466 = _19916;
                                break;
                            }
                        }
                    }
                    float _19918;
                    if (_19916 == 4294967295u)
                    {
                        _19918 = -1.0f;
                    }
                    else
                    {
                        float _19917;
                        if (_19916 == 0u)
                        {
                            _19917 = -1.0f;
                        }
                        else
                        {
                            _19917 = float((_19916 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _19918 = _19917;
                    }
                    _19931 = _19918;
                    break;
                } while(false);
                bool _6430 = _19931 < 0.0f;
                float _19932;
                if (_6430)
                {
                    _19932 = 0.0f;
                }
                else
                {
                    _19932 = _19931 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12800_dummy_parameter;
                uint _12832_dummy_parameter;
                float4 _19969;
                if ((_6430 && _6419) && _6422)
                {
                    uint _12864_dummy_parameter;
                    float _12888 = log((r_depth_tm1.Load(int3(int2(floor(_19045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12864_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12896_dummy_parameter;
                    float _12920 = log((r_depth_tp1.Load(int3(int2(floor(_19047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12896_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _19970;
                    if (_12888 > (_12920 + 0.07999999821186065673828125f))
                    {
                        float4 _18778 = _19936;
                        _18778.x = 0.0f;
                        _19970 = _18778;
                    }
                    else
                    {
                        float4 _19971;
                        if (_12920 > (_12888 + 0.07999999821186065673828125f))
                        {
                            float4 _18780 = _19936;
                            _18780.y = 0.0f;
                            _19971 = _18780;
                        }
                        else
                        {
                            _19971 = _19936;
                        }
                        _19970 = _19971;
                    }
                    _19969 = _19970;
                }
                else
                {
                    _19969 = _19936;
                }
                float _6482 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6484 = _19931 >= 0.0f;
                float _19952;
                if (_6484)
                {
                    _19952 = _19931 - _6482;
                }
                else
                {
                    float _19948;
                    if (_6419)
                    {
                        float _19947;
                        _19947 = 2.0f;
                        float _12978;
                        for (int _19946 = 0; _19946 < 24; _19947 = _12978, _19946++)
                        {
                            float _12942 = float(_19946 & 7) * 0.785398185253143310546875f;
                            int _12944 = _19946 >> 3;
                            int _19949;
                            if (_12944 == 0)
                            {
                                _19949 = 16;
                            }
                            else
                            {
                                _19949 = (_12944 == 1) ? 48 : 96;
                            }
                            uint _12994_dummy_parameter;
                            _12978 = min(_19947, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19045 + ((cbFI_MvDepthLaneSizeRcp * float(_19949)) * float2(cos(_12942), sin(_12942))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12994_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _19948 = _19947;
                    }
                    else
                    {
                        _19948 = 0.0f;
                    }
                    _19952 = _19948;
                }
                float _19959;
                if (_6484)
                {
                    _19959 = _19931 - _6482;
                }
                else
                {
                    float _19955;
                    if (_6422)
                    {
                        float _19954;
                        _19954 = 2.0f;
                        float _13092;
                        for (int _19953 = 0; _19953 < 24; _19954 = _13092, _19953++)
                        {
                            float _13056 = float(_19953 & 7) * 0.785398185253143310546875f;
                            int _13058 = _19953 >> 3;
                            int _19956;
                            if (_13058 == 0)
                            {
                                _19956 = 16;
                            }
                            else
                            {
                                _19956 = (_13058 == 1) ? 48 : 96;
                            }
                            uint _13124_dummy_parameter;
                            _13092 = min(_19954, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19047 + ((cbFI_MvDepthLaneSizeRcp * float(_19956)) * float2(cos(_13056), sin(_13056))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13124_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _19955 = _19954;
                    }
                    else
                    {
                        _19955 = 0.0f;
                    }
                    _19959 = _19955;
                }
                float _19960;
                if (_6419)
                {
                    uint _13156_dummy_parameter;
                    _19960 = r_depth_tm1.Load(int3(int2(floor(_19045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13156_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _19960 = 0.0f;
                }
                float _19961;
                if (_6422)
                {
                    uint _13175_dummy_parameter;
                    _19961 = r_depth_tp1.Load(int3(int2(floor(_19047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13175_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _19961 = 0.0f;
                }
                bool _6539;
                if (_6419)
                {
                    _6539 = _19960 > ((exp((_19952 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6539 = _6419;
                }
                float4 _19977;
                if (_6539)
                {
                    float4 _18782 = _19969;
                    _18782.x = 0.0f;
                    _19977 = _18782;
                }
                else
                {
                    _19977 = _19969;
                }
                bool _6551;
                if (_6422)
                {
                    _6551 = _19961 > ((exp((_19959 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6551 = _6422;
                }
                float4 _19979;
                if (_6551)
                {
                    float4 _18784 = _19977;
                    _18784.y = 0.0f;
                    _19979 = _18784;
                }
                else
                {
                    _19979 = _19977;
                }
                float4 _20042;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6484)
                {
                    bool _6571;
                    if (_6419)
                    {
                        _6571 = _19960 < ((exp((_19952 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6571 = _6419;
                    }
                    float4 _19981;
                    if (_6571)
                    {
                        float4 _18786 = _19979;
                        _18786.x = 0.0f;
                        _19981 = _18786;
                    }
                    else
                    {
                        _19981 = _19979;
                    }
                    bool _6583;
                    if (_6422)
                    {
                        _6583 = _19961 < ((exp((_19959 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6583 = _6422;
                    }
                    float4 _20043;
                    if (_6583)
                    {
                        float4 _18788 = _19981;
                        _18788.y = 0.0f;
                        _20043 = _18788;
                    }
                    else
                    {
                        _20043 = _19981;
                    }
                    _20042 = _20043;
                }
                else
                {
                    _20042 = _19979;
                }
                _21115 = float3(_19932, log((r_depth_tm1.Load(int3(int2(floor(_19045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12800_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_19047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12832_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _20041 = _20042;
            }
            else
            {
                _21115 = float3(0.0f, 0.0f, 0.5f);
                _20041 = _19936;
            }
            bool _6594 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6343;
            bool _6600;
            if (_6594)
            {
                _6600 = _6397 || _6403;
            }
            else
            {
                _6600 = _6594;
            }
            float4 _20084;
            if (_6600)
            {
                float _20036;
                do
                {
                    uint4 _13354 = r_warped_motion_qdata_tp1.Load(int3(_19266, 0));
                    uint _13355 = _13354.x;
                    if (_13355 != 0u)
                    {
                        float _20035;
                        if (_13355 == 0u)
                        {
                            _20035 = -1.0f;
                        }
                        else
                        {
                            _20035 = float((_13355 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20036 = _20035;
                        break;
                    }
                    int _20018;
                    uint _20019;
                    _20019 = _13355;
                    _20018 = -1;
                    uint _20034;
                    for (; _20018 <= 1; _20019 = _20034, _20018++)
                    {
                        _20034 = _20019;
                        for (int _20032 = -1; _20032 <= 1; )
                        {
                            _20034 = max(_20034, r_warped_motion_qdata_tp1.Load(int3(clamp(_19266 + int2(_20032, _20018), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20032++;
                            continue;
                        }
                    }
                    if (_20019 != 0u)
                    {
                        float _20031;
                        if (_20019 == 0u)
                        {
                            _20031 = -1.0f;
                        }
                        else
                        {
                            _20031 = float((_20019 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20036 = _20031;
                        break;
                    }
                    uint _20021;
                    _20021 = 4294967295u;
                    uint _22467;
                    for (int _20020 = 0; _20020 < 8; _20021 = _22467, _20020++)
                    {
                        int _20024 = 0;
                        for (;;)
                        {
                            if (_20024 < 5)
                            {
                                int2 _13305 = _19266 + (_1243[_20020] * _1252[_20024].xx);
                                bool _13308 = any(bool2(_13305.x < int2(0, 0).x, _13305.y < int2(0, 0).y));
                                bool _13316;
                                if (!_13308)
                                {
                                    _13316 = any(bool2(_13305.x >= cbFI_MvDepthLaneSize.x, _13305.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13316 = _13308;
                                }
                                if (_13316)
                                {
                                    _22467 = _20021;
                                    break;
                                }
                                uint4 _13394 = r_warped_motion_qdata_tp1.Load(int3(_13305, 0));
                                uint _13395 = _13394.x;
                                if (_13395 != 0u)
                                {
                                    _22467 = min(_20021, _13395);
                                    break;
                                }
                                _20024++;
                                continue;
                            }
                            else
                            {
                                _22467 = _20021;
                                break;
                            }
                        }
                    }
                    float _20023;
                    if (_20021 == 4294967295u)
                    {
                        _20023 = -1.0f;
                    }
                    else
                    {
                        float _20022;
                        if (_20021 == 0u)
                        {
                            _20022 = -1.0f;
                        }
                        else
                        {
                            _20022 = float((_20021 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20023 = _20022;
                    }
                    _20036 = _20023;
                    break;
                } while(false);
                float4 _20085;
                if (_20036 >= 0.0f)
                {
                    float _13416 = (exp((_20036 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6619;
                    if (_6397)
                    {
                        uint _13423_dummy_parameter;
                        _6619 = r_depth_tm1.Load(int3(int2(floor(_19048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13423_dummy_parameter))))), 0)).x > _13416;
                    }
                    else
                    {
                        _6619 = _6397;
                    }
                    float4 _20054;
                    if (_6619)
                    {
                        float4 _18790 = _20041;
                        _18790.z = 0.0f;
                        _20054 = _18790;
                    }
                    else
                    {
                        _20054 = _20041;
                    }
                    bool _6631;
                    if (_6403)
                    {
                        uint _13442_dummy_parameter;
                        _6631 = r_depth_tp1.Load(int3(int2(floor(_19049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13442_dummy_parameter))))), 0)).x > _13416;
                    }
                    else
                    {
                        _6631 = _6403;
                    }
                    float4 _20086;
                    if (_6631)
                    {
                        float4 _18792 = _20054;
                        _18792.w = 0.0f;
                        _20086 = _18792;
                    }
                    else
                    {
                        _20086 = _20054;
                    }
                    _20085 = _20086;
                }
                else
                {
                    _20085 = _20041;
                }
                _20084 = _20085;
            }
            else
            {
                _20084 = _20041;
            }
            bool _6639 = _6385 != _6391;
            bool _6646;
            if (_6639)
            {
                _6646 = _6385 ? _6331 : _6334;
            }
            else
            {
                _6646 = _6639;
            }
            bool _6653;
            if (_6646)
            {
                _6653 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6653 = _6646;
            }
            float4 _20187;
            if (_6653)
            {
                bool2 _6658 = _6385.xx;
                float2 _6659 = float2(_6658.x ? _19045.x : _19047.x, _6658.y ? _19045.y : _19047.y);
                float _20068;
                if (_6385)
                {
                    uint _13461_dummy_parameter;
                    _20068 = r_depth_tm1.Load(int3(int2(floor(_6659 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13461_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13477_dummy_parameter;
                    _20068 = r_depth_tp1.Load(int3(int2(floor(_6659 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13477_dummy_parameter))))), 0)).x;
                }
                float4x4 _20075;
                if (_6385)
                {
                    float4x4 _20064;
                    do
                    {
                        float4x4 _13491;
                        bool _20063;
                        do
                        {
                            _13491 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20063 = false;
                                break;
                            }
                            uint _13525 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13525 + 32u) * 4 + 0) != 1u)
                            {
                                _20063 = false;
                                break;
                            }
                            uint _20060;
                            _20060 = 0u;
                            for (; _20060 < 4u; _20060++)
                            {
                                for (uint _20061 = 0u; _20061 < 4u; )
                                {
                                    _13491[_20060][_20061] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13525 + 16u) + (_20060 * 4u)) + _20061) * 4 + 0));
                                    _20061++;
                                    continue;
                                }
                            }
                            _20063 = true;
                            break;
                        } while(false);
                        if (_20063)
                        {
                            _20064 = _13491;
                            break;
                        }
                        _20064 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20075 = _20064;
                }
                else
                {
                    float4x4 _20059;
                    do
                    {
                        float4x4 _13597;
                        bool _20058;
                        do
                        {
                            _13597 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20058 = false;
                                break;
                            }
                            uint _13631 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13631 + 32u) * 4 + 0) != 1u)
                            {
                                _20058 = false;
                                break;
                            }
                            uint _20055;
                            _20055 = 0u;
                            for (; _20055 < 4u; _20055++)
                            {
                                for (uint _20056 = 0u; _20056 < 4u; )
                                {
                                    _13597[_20055][_20056] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13631 + (_20055 * 4u)) + _20056) * 4 + 0));
                                    _20056++;
                                    continue;
                                }
                            }
                            _20058 = true;
                            break;
                        } while(false);
                        if (_20058)
                        {
                            _20059 = _13597;
                            break;
                        }
                        _20059 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20075 = _20059;
                }
                float2 _20076;
                do
                {
                    float _13708 = _6659.x;
                    float _13711 = 1.0f - _6659.y;
                    float4 _13722 = mul(float4((float2(_13708, _13711) * 2.0f) - 1.0f.xx, _20068, 1.0f), _20075);
                    float _13724 = _13722.w;
                    if (!(_13724 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20076 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13737 = ((_13722.xy / _13724.xx) + 1.0f.xx) * 0.5f;
                    _20076 = float2(_13737.x - _13708, _13711 - _13737.y);
                    break;
                } while(false);
                float2 _6689 = float2(cbFI_DisplaySize);
                float4 _20188;
                if (!(length(((_6659 + _20076) - float2(_6658.x ? _19047.x : _19045.x, _6658.y ? _19047.y : _19045.y)) * _6689) <= ((0.100000001490116119384765625f * length(_20076 * _6689)) + 8.0f)))
                {
                    float4 _20189;
                    if (_6385)
                    {
                        float4 _18802 = _20084;
                        _18802.x = 0.0f;
                        _20189 = _18802;
                    }
                    else
                    {
                        float4 _18804 = _20084;
                        _18804.y = 0.0f;
                        _20189 = _18804;
                    }
                    _20188 = _20189;
                }
                else
                {
                    _20188 = _20084;
                }
                _20187 = _20188;
            }
            else
            {
                _20187 = _20084;
            }
            float4 _6714 = _19798 * _20187;
            float _6716 = dot(_6714, 1.0f.xxxx);
            float4 _20529;
            bool _20835;
            if (_6716 > 0.0f)
            {
                _20835 = _19489;
                _20529 = _6714 / _6716.xxxx;
            }
            else
            {
                bool _6727 = any(bool4(_20187.x < 1.0f.xxxx.x, _20187.y < 1.0f.xxxx.y, _20187.z < 1.0f.xxxx.z, _20187.w < 1.0f.xxxx.w));
                if (_6727)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13759;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13759);
                    }
                }
                bool4 _22772 = _6727.xxxx;
                _20835 = _6727 ? true : _19489;
                _20529 = float4(_22772.x ? 0.0f.xxxx.x : _19798.x, _22772.y ? 0.0f.xxxx.y : _19798.y, _22772.z ? 0.0f.xxxx.z : _19798.z, _22772.w ? 0.0f.xxxx.w : _19798.w);
            }
            _21006 = _21115;
            _20834 = _20835;
            _20528 = _20529;
        }
        else
        {
            _21006 = float3(0.0f, 0.0f, 0.5f);
            _20834 = _19489;
            _20528 = _19798;
        }
        uint _6736 = (cbFI_pad0 >> 24u) & 31u;
        uint _6740 = (cbFI_pad0 >> 16u) & 255u;
        bool _6742 = _6736 != 0u;
        bool _6744 = _6740 == 12u;
        bool _6747 = _6740 == 13u;
        float4 _20549;
        if ((_6742 || _6744) || _6747)
        {
            float _20195;
            do
            {
                bool _13843 = all(bool2(_19048.x > 0.0f.xx.x, _19048.y > 0.0f.xx.y));
                bool _13849;
                if (_13843)
                {
                    _13849 = all(bool2(_19048.x < 1.0f.xx.x, _19048.y < 1.0f.xx.y));
                }
                else
                {
                    _13849 = _13843;
                }
                bool _13780 = !_13849;
                bool _13787;
                if (!_13780)
                {
                    bool _13854 = all(bool2(_19049.x > 0.0f.xx.x, _19049.y > 0.0f.xx.y));
                    bool _13860;
                    if (_13854)
                    {
                        _13860 = all(bool2(_19049.x < 1.0f.xx.x, _19049.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13860 = _13854;
                    }
                    _13787 = !_13860;
                }
                else
                {
                    _13787 = _13780;
                }
                if (_13787)
                {
                    _20195 = 0.0f;
                    break;
                }
                uint _13867_dummy_parameter;
                uint _13883_dummy_parameter;
                float4x4 _20194;
                do
                {
                    float4x4 _13897;
                    bool _20193;
                    do
                    {
                        _13897 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20193 = false;
                            break;
                        }
                        uint _13931 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_13931 + 32u) * 4 + 0) != 1u)
                        {
                            _20193 = false;
                            break;
                        }
                        uint _20190;
                        _20190 = 0u;
                        for (; _20190 < 4u; _20190++)
                        {
                            for (uint _20191 = 0u; _20191 < 4u; )
                            {
                                _13897[_20190][_20191] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13931 + 16u) + (_20190 * 4u)) + _20191) * 4 + 0));
                                _20191++;
                                continue;
                            }
                        }
                        _20193 = true;
                        break;
                    } while(false);
                    if (_20193)
                    {
                        _20194 = _13897;
                        break;
                    }
                    _20194 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13808 = mul(float4((float2(_19048.x, 1.0f - _19048.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19048 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13867_dummy_parameter))))), 0)).x, 1.0f), _20194);
                float _13810 = _13808.w;
                if (abs(_13810) < 9.9999999747524270787835121154785e-07f)
                {
                    _20195 = 0.0f;
                    break;
                }
                float _13821 = abs(cbFI_DeviceToViewDepth.y / ((_13808.z / _13810) - cbFI_DeviceToViewDepth.x));
                float _13824 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13883_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20195 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13821 - _13824) / max(max(_13821, _13824), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14033 = all(bool2(_19049.x > 0.0f.xx.x, _19049.y > 0.0f.xx.y));
            bool _14039;
            if (_14033)
            {
                _14039 = all(bool2(_19049.x < 1.0f.xx.x, _19049.y < 1.0f.xx.y));
            }
            else
            {
                _14039 = _14033;
            }
            float _20196;
            if (_14039)
            {
                uint _14046_dummy_parameter;
                _20196 = length((_7867 + (r_motion_tp1.Load(int3(int2(floor(_19049 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14046_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20196 = 1000000.0f;
            }
            float _20211;
            if ((_6736 & 1u) != 0u)
            {
                _20211 = _20195;
            }
            else
            {
                _20211 = 1.0f;
            }
            float _20212;
            if ((_6736 & 2u) != 0u)
            {
                _20212 = _20211 * (1.0f - smoothstep(2.0f, 8.0f, _20196));
            }
            else
            {
                _20212 = _20211;
            }
            float _20213;
            if ((_6736 & 4u) != 0u)
            {
                _20213 = _20212 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8588 - _8596) - length(_8572 - _8580))));
            }
            else
            {
                _20213 = _20212;
            }
            float _20543;
            if ((_6736 & 8u) != 0u)
            {
                _20543 = lerp(1.0f, _20213, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8572 - _8580)));
            }
            else
            {
                _20543 = _20213;
            }
            bool _6822 = (_6736 & 16u) != 0u;
            bool _6831;
            if (_6822)
            {
                _6831 = length(_19043 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6831 = _6822;
            }
            float _22774 = _6831 ? 1.0f : _20543;
            bool _6837 = _6742 && _10969;
            bool _6842;
            if (_6837)
            {
                bool _14071 = all(bool2(_19045.x > 0.0f.xx.x, _19045.y > 0.0f.xx.y));
                bool _14077;
                if (_14071)
                {
                    _14077 = all(bool2(_19045.x < 1.0f.xx.x, _19045.y < 1.0f.xx.y));
                }
                else
                {
                    _14077 = _14071;
                }
                _6842 = _14077;
            }
            else
            {
                _6842 = _6837;
            }
            bool _6847;
            if (_6842)
            {
                bool _14082 = all(bool2(_19047.x > 0.0f.xx.x, _19047.y > 0.0f.xx.y));
                bool _14088;
                if (_14082)
                {
                    _14088 = all(bool2(_19047.x < 1.0f.xx.x, _19047.y < 1.0f.xx.y));
                }
                else
                {
                    _14088 = _14082;
                }
                _6847 = _14088;
            }
            else
            {
                _6847 = _6842;
            }
            float4 _20550;
            if (_6847)
            {
                float _6853 = _20528.x + _20528.y;
                float _6862 = (_20528.z + _20528.w) * (1.0f - _22774);
                float _20546;
                if (_6853 > 9.9999997473787516355514526367188e-06f)
                {
                    _20546 = _20528.x / _6853;
                }
                else
                {
                    _20546 = _5592;
                }
                _20550 = float4(_20528.x + (_6862 * _20546), _20528.y + (_6862 * (1.0f - _20546)), _20528.zw * _22774);
            }
            else
            {
                _20550 = _20528;
            }
            _20549 = _20550;
        }
        else
        {
            _20549 = _20528;
        }
        float3 _6923 = (((_8572 * _20549.x) + (_8580 * _20549.y)) + (_8588 * _20549.z)) + (_8596 * _20549.w);
        float3 _22083;
        if (_5608 && (_20564 > 0.0f))
        {
            uint _14095_dummy_parameter;
            float2 _14110 = r_motion_tp1.Load(int3(int2(floor(_5367 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14095_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _20826;
            if (_7895)
            {
                float2 _14155 = clamp((((_19022 + (_14110 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14158 = tan(_14155.x);
                _20826 = (float2(_14158 / cbFI_DeviceToViewDepth.z, (tan(_14155.y) * sqrt(1.0f + (_14158 * _14158))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _20826 = _19022 + (_14110 * cbFI_Timestep);
            }
            float2 _20827;
            if (_7895)
            {
                float2 _14234 = clamp((((_19022 + (_14110 * _5582)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14237 = tan(_14234.x);
                _20827 = (float2(_14237 / cbFI_DeviceToViewDepth.z, (tan(_14234.y) * sqrt(1.0f + (_14237 * _14237))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _20827 = _19022 + (_14110 * _5582);
            }
            _22083 = lerp(_6923, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _20826, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _20827, 0.0f).xyz, cbFI_Timestep.xxx), _20564.xxx);
        }
        else
        {
            _22083 = _6923;
        }
        float3 _22082;
        if (_20834)
        {
            float3 _14279 = r_current_interpolation_source.Load(int3(_4868, 0)).xyz;
            float3 _22084;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _10969)
            {
                uint _14286_dummy_parameter;
                float _20957;
                _20957 = r_depth_tm1.Load(int3(int2(floor(_19045 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14286_dummy_parameter))))), 0)).x;
                float _7004;
                for (int _20956 = 0; _20956 < 24; _20957 = _7004, _20956++)
                {
                    float _6976 = float(_20956 & 7) * 0.785398185253143310546875f;
                    int _6978 = _20956 >> 3;
                    int _22309;
                    if (_6978 == 0)
                    {
                        _22309 = 16;
                    }
                    else
                    {
                        _22309 = (_6978 == 1) ? 48 : 96;
                    }
                    uint _14306_dummy_parameter;
                    _7004 = min(_20957, r_depth_tm1.Load(int3(int2(floor(clamp(_19045 + ((cbFI_MvDepthLaneSizeRcp * float(_22309)) * float2(cos(_6976), sin(_6976))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14306_dummy_parameter))))), 0)).x);
                }
                float2 _20958;
                do
                {
                    float _14328 = 1.0f - _19045.y;
                    float4 _14339 = mul(float4((float2(_19045.x, _14328) * 2.0f) - 1.0f.xx, _20957, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14341 = _14339.w;
                    if (!(_14341 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20958 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14354 = ((_14339.xy / _14341.xx) + 1.0f.xx) * 0.5f;
                    _20958 = float2(_14354.x - _19045.x, _14328 - _14354.y);
                    break;
                } while(false);
                float2 _7015 = _19045 + _20958;
                bool _14372 = all(bool2(_7015.x > 0.0f.xx.x, _7015.y > 0.0f.xx.y));
                bool _14378;
                if (_14372)
                {
                    _14378 = all(bool2(_7015.x < 1.0f.xx.x, _7015.y < 1.0f.xx.y));
                }
                else
                {
                    _14378 = _14372;
                }
                float3 _22085;
                if (_14378)
                {
                    float _7021 = abs(cbFI_DeviceToViewDepth.y / (_20957 - cbFI_DeviceToViewDepth.x));
                    uint _14398_dummy_parameter;
                    int2 _14398 = int2(spvTextureSize(r_depth_m2, uint(0), _14398_dummy_parameter));
                    float _7025 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7015 * float2(_14398))), int2(0, 0), _14398 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22090;
                    if (abs(_7025 - _7021) <= (0.20000000298023223876953125f * max(_7025, _7021)))
                    {
                        uint _14432_dummy_parameter;
                        int2 _14432 = int2(spvTextureSize(r_colour_m2, uint(0), _14432_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14455;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14455);
                        }
                        _22090 = r_colour_m2.Load(int3(clamp(int2(floor(_7015 * float2(_14432))), int2(0, 0), _14432 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14465;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14465);
                        }
                        _22090 = _14279;
                    }
                    _22085 = _22090;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14475;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14475);
                    }
                    _22085 = _14279;
                }
                _22084 = _22085;
            }
            else
            {
                _22084 = _14279;
            }
            _22082 = _22084;
        }
        else
        {
            _22082 = _22083;
        }
        bool _7050 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22081;
        float _22157;
        if (_7050)
        {
            float _14661;
            float2 _7054 = float2(cbFI_DisplaySize);
            float3 _20997;
            do
            {
                bool _14722;
                float4x4 _20965;
                do
                {
                    float4x4 _14698;
                    bool _20964;
                    do
                    {
                        _14698 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14722 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14722)
                        {
                            _20964 = false;
                            break;
                        }
                        uint _14732 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14732 + 32u) * 4 + 0) != 1u)
                        {
                            _20964 = false;
                            break;
                        }
                        uint _20961;
                        _20961 = 0u;
                        for (; _20961 < 4u; _20961++)
                        {
                            for (uint _20962 = 0u; _20962 < 4u; )
                            {
                                _14698[_20961][_20962] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14732 + (_20961 * 4u)) + _20962) * 4 + 0));
                                _20962++;
                                continue;
                            }
                        }
                        _20964 = true;
                        break;
                    } while(false);
                    if (_20964)
                    {
                        _20965 = _14698;
                        break;
                    }
                    _20965 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float _14809;
                float _14812;
                float4 _14822;
                float4x4 _14529 = spvInverse(_20965);
                float2 _20966;
                do
                {
                    _14809 = _5367.x;
                    _14812 = 1.0f - _5367.y;
                    _14822 = float4((float2(_14809, _14812) * 2.0f) - 1.0f.xx, 1.0000000116860974230803549289703e-07f, 1.0f);
                    float4 _14823 = mul(_14822, _20965);
                    float _14825 = _14823.w;
                    if (!(_14825 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20966 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14838 = ((_14823.xy / _14825.xx) + 1.0f.xx) * 0.5f;
                    _20966 = float2(_14838.x - _14809, _14812 - _14838.y);
                    break;
                } while(false);
                float2 _20967;
                do
                {
                    float4 _14875 = mul(_14822, _14529);
                    float _14877 = _14875.w;
                    if (!(_14877 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20967 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14890 = ((_14875.xy / _14877.xx) + 1.0f.xx) * 0.5f;
                    _20967 = float2(_14890.x - _14809, _14812 - _14890.y);
                    break;
                } while(false);
                float2 _14537 = abs(_20966);
                bool2 _22775 = any(bool2(_14537.x > 4.0f.xx.x, _14537.y > 4.0f.xx.y)).xx;
                float2 _14543 = abs(_20967);
                bool2 _22777 = any(bool2(_14543.x > 4.0f.xx.x, _14543.y > 4.0f.xx.y)).xx;
                float2 _14904[3];
                _14904[0] = _5367;
                float2 _15024 = clamp(_5367, 0.0f.xx, 1.0f.xx);
                uint _15032_dummy_parameter;
                _14904[1] = _5367 - ((r_motion_tp1.Load(int3(int2(floor(_15024 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15032_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5592);
                _14904[2] = _5367 - (float2(_22775.x ? 0.0f.xx.x : _20966.x, _22775.y ? 0.0f.xx.y : _20966.y) * _5592);
                float _20973;
                float2 _20974;
                _20974 = _5367;
                _20973 = 1000000000.0f;
                float _22779;
                float2 _22781;
                float _22782;
                int _20972 = 0;
                float _22301 = -1.0f;
                for (; _20972 < 3; _22301 = _22779, _20974 = _22781, _20973 = _22782, _20972++)
                {
                    float2 _22291;
                    _22291 = _14904[_20972];
                    for (int _22290 = 0; _22290 < 30; )
                    {
                        uint _15546_dummy_parameter;
                        _22291 += (((_5367 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_22291, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15546_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5592)) - _22291) * 0.699999988079071044921875f);
                        _22290++;
                        continue;
                    }
                    float2 _15976 = clamp(_22291, 0.0f.xx, 1.0f.xx);
                    uint _15984_dummy_parameter;
                    bool _16414 = all(bool2(_22291.x > 0.0f.xx.x, _22291.y > 0.0f.xx.y));
                    bool _16420;
                    if (_16414)
                    {
                        _16420 = all(bool2(_22291.x < 1.0f.xx.x, _22291.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _16420 = _16414;
                    }
                    float _22293;
                    if (_16420)
                    {
                        _22293 = length(((_22291 + ((r_motion_tp1.Load(int3(int2(floor(_15976 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15984_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5592)) - _5367) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22293 = 1000000000.0f;
                    }
                    uint _16431_dummy_parameter;
                    float _16471 = log((r_depth_tp1.Load(int3(int2(floor(_15976 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16431_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _14984 = _22293 < 0.3499999940395355224609375f;
                    bool _14986 = _20973 < 0.3499999940395355224609375f;
                    bool _14996;
                    if (_14984)
                    {
                        _14996 = (!_14986) || (_16471 > _22301);
                    }
                    else
                    {
                        _14996 = _14984;
                    }
                    bool _15009;
                    if (!_14996)
                    {
                        _15009 = ((!_14984) && (!_14986)) && (_22293 < _20973);
                    }
                    else
                    {
                        _15009 = _14996;
                    }
                    _22779 = _15009 ? _16471 : _22301;
                    bool2 _22780 = _15009.xx;
                    _22781 = float2(_22780.x ? _22291.x : _20974.x, _22780.y ? _22291.y : _20974.y);
                    _22782 = _15009 ? _22293 : _20973;
                }
                float2 _16473[3];
                _16473[0] = _5367;
                float2 _20993;
                do
                {
                    bool _20983;
                    do
                    {
                        bool _16720 = all(bool2(_15024.x > 0.0f.xx.x, _15024.y > 0.0f.xx.y));
                        bool _16726;
                        if (_16720)
                        {
                            _16726 = all(bool2(_15024.x < 1.0f.xx.x, _15024.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _16726 = _16720;
                        }
                        if (!_16726)
                        {
                            _20983 = false;
                            break;
                        }
                        uint _16733_dummy_parameter;
                        float4x4 _20981;
                        do
                        {
                            float4x4 _16747;
                            bool _20980;
                            do
                            {
                                _16747 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14722)
                                {
                                    _20980 = false;
                                    break;
                                }
                                uint _16781 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_16781 + 32u) * 4 + 0) != 1u)
                                {
                                    _20980 = false;
                                    break;
                                }
                                uint _20977;
                                _20977 = 0u;
                                for (; _20977 < 4u; _20977++)
                                {
                                    for (uint _20978 = 0u; _20978 < 4u; )
                                    {
                                        _16747[_20977][_20978] = asfloat(rw_nfru_diagnostics.Load<uint>(((_16781 + (_20977 * 4u)) + _20978) * 4 + 0));
                                        _20978++;
                                        continue;
                                    }
                                }
                                _20980 = true;
                                break;
                            } while(false);
                            if (_20980)
                            {
                                _20981 = _16747;
                                break;
                            }
                            _20981 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _20982;
                        do
                        {
                            float _16858 = _15024.x;
                            float _16861 = 1.0f - _15024.y;
                            float4 _16872 = mul(float4((float2(_16858, _16861) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15024 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16733_dummy_parameter))))), 0)).x, 1.0f), _20981);
                            float _16874 = _16872.w;
                            if (!(_16874 > 9.9999999747524270787835121154785e-07f))
                            {
                                _20982 = 1000000.0f.xx;
                                break;
                            }
                            float2 _16887 = ((_16872.xy / _16874.xx) + 1.0f.xx) * 0.5f;
                            _20982 = float2(_16887.x - _16858, _16861 - _16887.y);
                            break;
                        } while(false);
                        float2 _16684 = abs(_20982);
                        if (any(bool2(_16684.x > 100000.0f.xx.x, _16684.y > 100000.0f.xx.y)))
                        {
                            _20983 = false;
                            break;
                        }
                        float _16692 = length(_20982 * _7054);
                        uint _16907_dummy_parameter;
                        bool _16706 = _16692 > ((8.0f * _7054.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _16713;
                        if (_16706)
                        {
                            _16713 = length((r_motion_tp1.Load(int3(int2(floor(_15024 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16907_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7054) < (0.20000000298023223876953125f * _16692);
                        }
                        else
                        {
                            _16713 = _16706;
                        }
                        _20983 = _16713;
                        break;
                    } while(false);
                    if (_20983)
                    {
                        uint _16938_dummy_parameter;
                        _20993 = -(r_motion_tp1.Load(int3(int2(floor(_15024 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16938_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _16965_dummy_parameter;
                    float2 _20992;
                    do
                    {
                        float _16984 = _15024.x;
                        float _16987 = 1.0f - _15024.y;
                        float4 _16998 = mul(float4((float2(_16984, _16987) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15024 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _16965_dummy_parameter))))), 0)).x, 1.0f), _14529);
                        float _17000 = _16998.w;
                        if (!(_17000 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20992 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17013 = ((_16998.xy / _17000.xx) + 1.0f.xx) * 0.5f;
                        _20992 = float2(_17013.x - _16984, _16987 - _17013.y);
                        break;
                    } while(false);
                    float2 _16651 = abs(_20992);
                    bool2 _16655 = any(bool2(_16651.x > 4.0f.xx.x, _16651.y > 4.0f.xx.y)).xx;
                    _20993 = float2(_16655.x ? 0.0f.xx.x : _20992.x, _16655.y ? 0.0f.xx.y : _20992.y);
                    break;
                } while(false);
                _16473[1] = _5367 - (_20993 * cbFI_Timestep);
                _16473[2] = _5367 - (float2(_22777.x ? 0.0f.xx.x : _20967.x, _22777.y ? 0.0f.xx.y : _20967.y) * cbFI_Timestep);
                float _20995;
                float2 _20996;
                _20996 = _5367;
                _20995 = 1000000000.0f;
                float _22783;
                float2 _22785;
                float _22786;
                float4x4 _17261;
                float4x4 _17699;
                int _20994 = 0;
                float _22228 = -1.0f;
                for (; _20994 < 3; _22228 = _22783, _20996 = _22785, _20995 = _22786, _20994++)
                {
                    float2 _22178;
                    _22178 = _16473[_20994];
                    float2 _17070;
                    for (int _22177 = 0; _22177 < 30; _22178 = _17070, _22177++)
                    {
                        float2 _22269;
                        do
                        {
                            float2 _17150 = clamp(_22178, 0.0f.xx, 1.0f.xx);
                            bool _22259;
                            do
                            {
                                bool _17234 = all(bool2(_17150.x > 0.0f.xx.x, _17150.y > 0.0f.xx.y));
                                bool _17240;
                                if (_17234)
                                {
                                    _17240 = all(bool2(_17150.x < 1.0f.xx.x, _17150.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17240 = _17234;
                                }
                                if (!_17240)
                                {
                                    _22259 = false;
                                    break;
                                }
                                uint _17247_dummy_parameter;
                                float4x4 _22257;
                                do
                                {
                                    bool _22256;
                                    do
                                    {
                                        _17261 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14722)
                                        {
                                            _22256 = false;
                                            break;
                                        }
                                        uint _17295 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17295 + 32u) * 4 + 0) != 1u)
                                        {
                                            _22256 = false;
                                            break;
                                        }
                                        uint _22253;
                                        _22253 = 0u;
                                        for (; _22253 < 4u; _22253++)
                                        {
                                            for (uint _22254 = 0u; _22254 < 4u; )
                                            {
                                                _17261[_22253][_22254] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17295 + (_22253 * 4u)) + _22254) * 4 + 0));
                                                _22254++;
                                                continue;
                                            }
                                        }
                                        _22256 = true;
                                        break;
                                    } while(false);
                                    if (_22256)
                                    {
                                        _22257 = _17261;
                                        break;
                                    }
                                    _22257 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _22258;
                                do
                                {
                                    float _17372 = _17150.x;
                                    float _17375 = 1.0f - _17150.y;
                                    float4 _17386 = mul(float4((float2(_17372, _17375) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17150 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17247_dummy_parameter))))), 0)).x, 1.0f), _22257);
                                    float _17388 = _17386.w;
                                    if (!(_17388 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _22258 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _17401 = ((_17386.xy / _17388.xx) + 1.0f.xx) * 0.5f;
                                    _22258 = float2(_17401.x - _17372, _17375 - _17401.y);
                                    break;
                                } while(false);
                                float2 _17198 = abs(_22258);
                                if (any(bool2(_17198.x > 100000.0f.xx.x, _17198.y > 100000.0f.xx.y)))
                                {
                                    _22259 = false;
                                    break;
                                }
                                float _17206 = length(_22258 * _7054);
                                uint _17421_dummy_parameter;
                                bool _17220 = _17206 > ((8.0f * _7054.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17227;
                                if (_17220)
                                {
                                    _17227 = length((r_motion_tp1.Load(int3(int2(floor(_17150 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17421_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7054) < (0.20000000298023223876953125f * _17206);
                                }
                                else
                                {
                                    _17227 = _17220;
                                }
                                _22259 = _17227;
                                break;
                            } while(false);
                            if (_22259)
                            {
                                uint _17452_dummy_parameter;
                                _22269 = -(r_motion_tp1.Load(int3(int2(floor(_17150 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17452_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _17479_dummy_parameter;
                            float2 _22268;
                            do
                            {
                                float _17498 = _17150.x;
                                float _17501 = 1.0f - _17150.y;
                                float4 _17512 = mul(float4((float2(_17498, _17501) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17150 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17479_dummy_parameter))))), 0)).x, 1.0f), _14529);
                                float _17514 = _17512.w;
                                if (!(_17514 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22268 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17527 = ((_17512.xy / _17514.xx) + 1.0f.xx) * 0.5f;
                                _22268 = float2(_17527.x - _17498, _17501 - _17527.y);
                                break;
                            } while(false);
                            float2 _17165 = abs(_22268);
                            bool2 _17169 = any(bool2(_17165.x > 4.0f.xx.x, _17165.y > 4.0f.xx.y)).xx;
                            _22269 = float2(_17169.x ? 0.0f.xx.x : _22268.x, _17169.y ? 0.0f.xx.y : _22268.y);
                            break;
                        } while(false);
                        _17070 = _22178 + (((_5367 - (_22269 * cbFI_Timestep)) - _22178) * 0.699999988079071044921875f);
                    }
                    float2 _17588;
                    float2 _22195;
                    do
                    {
                        _17588 = clamp(_22178, 0.0f.xx, 1.0f.xx);
                        bool _22185;
                        do
                        {
                            bool _17672 = all(bool2(_17588.x > 0.0f.xx.x, _17588.y > 0.0f.xx.y));
                            bool _17678;
                            if (_17672)
                            {
                                _17678 = all(bool2(_17588.x < 1.0f.xx.x, _17588.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _17678 = _17672;
                            }
                            if (!_17678)
                            {
                                _22185 = false;
                                break;
                            }
                            uint _17685_dummy_parameter;
                            float4x4 _22183;
                            do
                            {
                                bool _22182;
                                do
                                {
                                    _17699 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14722)
                                    {
                                        _22182 = false;
                                        break;
                                    }
                                    uint _17733 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_17733 + 32u) * 4 + 0) != 1u)
                                    {
                                        _22182 = false;
                                        break;
                                    }
                                    uint _22179;
                                    _22179 = 0u;
                                    for (; _22179 < 4u; _22179++)
                                    {
                                        for (uint _22180 = 0u; _22180 < 4u; )
                                        {
                                            _17699[_22179][_22180] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17733 + (_22179 * 4u)) + _22180) * 4 + 0));
                                            _22180++;
                                            continue;
                                        }
                                    }
                                    _22182 = true;
                                    break;
                                } while(false);
                                if (_22182)
                                {
                                    _22183 = _17699;
                                    break;
                                }
                                _22183 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _22184;
                            do
                            {
                                float _17813 = 1.0f - _17588.y;
                                float4 _17824 = mul(float4((float2(_17588.x, _17813) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17588 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17685_dummy_parameter))))), 0)).x, 1.0f), _22183);
                                float _17826 = _17824.w;
                                if (!(_17826 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22184 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17839 = ((_17824.xy / _17826.xx) + 1.0f.xx) * 0.5f;
                                _22184 = float2(_17839.x - _17588.x, _17813 - _17839.y);
                                break;
                            } while(false);
                            float2 _17636 = abs(_22184);
                            if (any(bool2(_17636.x > 100000.0f.xx.x, _17636.y > 100000.0f.xx.y)))
                            {
                                _22185 = false;
                                break;
                            }
                            float _17644 = length(_22184 * _7054);
                            uint _17859_dummy_parameter;
                            bool _17658 = _17644 > ((8.0f * _7054.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _17665;
                            if (_17658)
                            {
                                _17665 = length((r_motion_tp1.Load(int3(int2(floor(_17588 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17859_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7054) < (0.20000000298023223876953125f * _17644);
                            }
                            else
                            {
                                _17665 = _17658;
                            }
                            _22185 = _17665;
                            break;
                        } while(false);
                        if (_22185)
                        {
                            uint _17890_dummy_parameter;
                            _22195 = -(r_motion_tp1.Load(int3(int2(floor(_17588 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17890_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _17917_dummy_parameter;
                        float2 _22194;
                        do
                        {
                            float _17939 = 1.0f - _17588.y;
                            float4 _17950 = mul(float4((float2(_17588.x, _17939) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17588 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17917_dummy_parameter))))), 0)).x, 1.0f), _14529);
                            float _17952 = _17950.w;
                            if (!(_17952 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22194 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17965 = ((_17950.xy / _17952.xx) + 1.0f.xx) * 0.5f;
                            _22194 = float2(_17965.x - _17588.x, _17939 - _17965.y);
                            break;
                        } while(false);
                        float2 _17603 = abs(_22194);
                        bool2 _17607 = any(bool2(_17603.x > 4.0f.xx.x, _17603.y > 4.0f.xx.y)).xx;
                        _22195 = float2(_17607.x ? 0.0f.xx.x : _22194.x, _17607.y ? 0.0f.xx.y : _22194.y);
                        break;
                    } while(false);
                    bool _17983 = all(bool2(_22178.x > 0.0f.xx.x, _22178.y > 0.0f.xx.y));
                    bool _17989;
                    if (_17983)
                    {
                        _17989 = all(bool2(_22178.x < 1.0f.xx.x, _22178.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17989 = _17983;
                    }
                    float _22207;
                    if (_17989)
                    {
                        _22207 = length(((_22178 + (_22195 * cbFI_Timestep)) - _5367) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22207 = 1000000000.0f;
                    }
                    uint _18016_dummy_parameter;
                    float _18040 = log((r_depth_tm1.Load(int3(int2(floor(_17588 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18016_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _16553 = _22207 < 0.3499999940395355224609375f;
                    bool _16555 = _20995 < 0.3499999940395355224609375f;
                    bool _16565;
                    if (_16553)
                    {
                        _16565 = (!_16555) || (_18040 > _22228);
                    }
                    else
                    {
                        _16565 = _16553;
                    }
                    bool _16578;
                    if (!_16565)
                    {
                        _16578 = ((!_16553) && (!_16555)) && (_22207 < _20995);
                    }
                    else
                    {
                        _16578 = _16565;
                    }
                    _22783 = _16578 ? _18040 : _22228;
                    bool2 _22784 = _16578.xx;
                    _22785 = float2(_22784.x ? _22178.x : _20996.x, _22784.y ? _22178.y : _20996.y);
                    _22786 = _16578 ? _22207 : _20995;
                }
                float3 _18049 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _20974, 0.0f).xyz;
                float3 _18057 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _20996, 0.0f).xyz;
                uint _18064_dummy_parameter;
                uint _18095_dummy_parameter;
                float _14583 = exp((_20973 * (-2.0f)) * (_20973 * 2.0f));
                float _14590 = exp((_20995 * (-2.0f)) * (_20995 * 2.0f));
                float _14603 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_20996, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18095_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_20974, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18064_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14617 = ((_14583 * cbFI_Timestep) * ((1.0f - _14590) + ((_14590 * 2.0f) * _14603))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14627 = 1.0f - _14603;
                float _14634 = ((_14590 * _5592) * ((1.0f - _14583) + ((_14583 * 2.0f) * _14627))) + (9.9999997473787516355514526367188e-05f * _5592);
                float _14643 = (((_14583 * _14590) * 4.0f) * _14603) * _14627;
                _14661 = (_14643 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18057 - _18049, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14643)) * max(_14583, _14590));
                if (_6740 == 30u)
                {
                    _20997 = _18049;
                    break;
                }
                if (_6740 == 31u)
                {
                    _20997 = _18057;
                    break;
                }
                if (_6740 == 32u)
                {
                    _20997 = float3(_14583, _14590, _14603);
                    break;
                }
                _20997 = ((_18049 * _14617) + (_18057 * _14634)) / (_14617 + _14634).xxx;
                break;
            } while(false);
            _22157 = _14661;
            _22081 = _20997;
        }
        else
        {
            _22157 = 1.0f;
            _22081 = _22082;
        }
        uint _7070 = cbFI_pad0 & 255u;
        bool _21933;
        float3 _22080;
        if (_7070 != 0u)
        {
            float3 _7075 = r_present_backbuffer.Load(int3(_4868, 0)).xyz;
            float3 _7079 = r_current_interpolation_source.Load(int3(_4868, 0)).xyz;
            float3 _7083 = abs(_7075 - _7079);
            float3 _20998;
            if (_7070 == 2u)
            {
                _20998 = (abs(_7079) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _20998 = 0.000244140625f.xxx;
            }
            bool _7099 = any(bool3(_7083.x > _20998.x, _7083.y > _20998.y, _7083.z > _20998.z));
            bool3 _22787 = _7099.xxx;
            _22080 = float3(_22787.x ? _7075.x : _22081.x, _22787.y ? _7075.y : _22081.y, _22787.z ? _7075.z : _22081.z);
            _21933 = _7099;
        }
        else
        {
            _22080 = _22081;
            _21933 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18133;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18133);
        }
        float3 _22062;
        if (_6740 == 1u)
        {
            _22062 = lerp(_8572, _8580, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22063;
            if (_6740 == 2u)
            {
                _22063 = lerp(_8588, _8596, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22064;
                if (_6740 == 3u)
                {
                    _22064 = float(_21933).xxx;
                }
                else
                {
                    float3 _22065;
                    if (_6740 == 4u)
                    {
                        _22065 = float3(((_19043 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22066;
                        if (_6740 == 5u)
                        {
                            _22066 = float3(((_7867 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22067;
                            if (_6740 == 6u)
                            {
                                _22067 = float3(_20549.xy, _20549.z + _20549.w);
                            }
                            else
                            {
                                float3 _22068;
                                if (_6740 == 7u)
                                {
                                    _22068 = r_current_interpolation_source.Load(int3(_4868, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22069;
                                    if (_6740 == 8u)
                                    {
                                        _22069 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5367, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22070;
                                        if (_6744)
                                        {
                                            uint _18155_dummy_parameter;
                                            uint _18187_dummy_parameter;
                                            _22070 = float3(log((r_depth_tp1.Load(int3(int2(floor(_5367 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18155_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_5367 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18187_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22071;
                                            if (_6747)
                                            {
                                                _22071 = _8588;
                                            }
                                            else
                                            {
                                                float3 _22072;
                                                if (_6740 == 20u)
                                                {
                                                    _22072 = _8572;
                                                }
                                                else
                                                {
                                                    float3 _22073;
                                                    if (_6740 == 21u)
                                                    {
                                                        _22073 = _8580;
                                                    }
                                                    else
                                                    {
                                                        float3 _22074;
                                                        if (_6740 == 22u)
                                                        {
                                                            _22074 = _8596;
                                                        }
                                                        else
                                                        {
                                                            float3 _22075;
                                                            if (_6740 == 18u)
                                                            {
                                                                _22075 = _21516;
                                                            }
                                                            else
                                                            {
                                                                float3 _22076;
                                                                if (_6740 == 19u)
                                                                {
                                                                    _22076 = _21258;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22077;
                                                                    if (_6740 == 23u)
                                                                    {
                                                                        _22077 = _21006;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22078;
                                                                        if (_6740 == 24u)
                                                                        {
                                                                            uint _7243 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7248 = float(rw_nfru_diagnostics.Load<uint>((_7243 + 35u) * 4 + 0));
                                                                            float _20999;
                                                                            if (_7248 > 0.0f)
                                                                            {
                                                                                _20999 = float(rw_nfru_diagnostics.Load<uint>((_7243 + 34u) * 4 + 0)) / _7248;
                                                                            }
                                                                            else
                                                                            {
                                                                                _20999 = 0.0f;
                                                                            }
                                                                            _22078 = float3(float(rw_nfru_diagnostics.Load<uint>((_7243 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7243 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _20999);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22078 = _22080;
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
                                            _22070 = _22071;
                                        }
                                        _22069 = _22070;
                                    }
                                    _22068 = _22069;
                                }
                                _22067 = _22068;
                            }
                            _22066 = _22067;
                        }
                        _22065 = _22066;
                    }
                    _22064 = _22065;
                }
                _22063 = _22064;
            }
            _22062 = _22063;
        }
        float3 _22061;
        if ((_6740 >= 9u) && (_6740 <= 11u))
        {
            uint _7308 = 64u + uint((_19266.y * cbFI_MvDepthLaneSize.x) + _19266.x);
            uint _7312 = rw_nfru_diagnostics.Load<uint>(_7308 * 4 + 0) & 15u;
            float3 _22095;
            if (_6740 == 10u)
            {
                float3 _22060;
                if ((rw_nfru_diagnostics.Load<uint>(_7308 * 4 + 0) & 32u) != 0u)
                {
                    _22060 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22059;
                    if ((rw_nfru_diagnostics.Load<uint>(_7308 * 4 + 0) & 16u) != 0u)
                    {
                        _22059 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7333 = ((rw_nfru_diagnostics.Load<uint>(_7308 * 4 + 0) & 64u) != 0u).xxx;
                        _22059 = float3(_7333.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7333.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7333.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22060 = _22059;
                }
                _22095 = _22060;
            }
            else
            {
                float3 _22096;
                if (_6740 == 11u)
                {
                    uint _7346 = (rw_nfru_diagnostics.Load<uint>(_7308 * 4 + 0) >> 8u) & 15u;
                    uint _7349 = (rw_nfru_diagnostics.Load<uint>(_7308 * 4 + 0) >> 12u) & 15u;
                    float3 _22052;
                    if ((_7312 == 2u) || (_7312 == 3u))
                    {
                        _22052 = _4567[_7312];
                    }
                    else
                    {
                        bool _7361 = _7346 == 3u;
                        bool _7363 = _7349 == 3u;
                        float3 _22053;
                        if (_7361 && _7363)
                        {
                            _22053 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22054;
                            if (_7361)
                            {
                                _22054 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22055;
                                if (_7363)
                                {
                                    _22055 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22056;
                                    if ((_7346 == 4u) || (_7349 == 4u))
                                    {
                                        _22056 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22057;
                                        if ((_7346 == 1u) || (_7349 == 1u))
                                        {
                                            _22057 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _22789 = (_7312 == 1u).xxx;
                                            _22057 = float3(_22789.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _22789.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _22789.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22056 = _22057;
                                    }
                                    _22055 = _22056;
                                }
                                _22054 = _22055;
                            }
                            _22053 = _22054;
                        }
                        _22052 = _22053;
                    }
                    _22096 = _22052;
                }
                else
                {
                    _22096 = _4567[min(_7312, 7u)];
                }
                _22095 = _22096;
            }
            _22061 = _22095;
        }
        else
        {
            _22061 = _22062;
        }
        float4 _22099;
        if ((_6740 >= 14u) && (_6740 <= 16u))
        {
            float2 _22097;
            if (_6740 == 14u)
            {
                uint _7419_dummy_parameter;
                uint _7425_dummy_parameter;
                _22097 = r_flow_tm1.Load(int3(clamp(int2(floor(_5367 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7419_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7425_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22098;
                if (_6740 == 16u)
                {
                    uint _18263 = r_warped_flow_qdata_tm1.Load(int3(_5383, 0)).x & 2147483647u;
                    uint _18295 = uint(max((int((_18263 >> 16u) & 15u) - 6), 0));
                    _22098 = ((float2(float((1 - (2 * int((_18263 >> 15u) & 1u))) * int(((_18263 >> uint(7)) & 127u) << _18295)), float((1 - (2 * int((_18263 >> 14u) & 1u))) * int((_18263 & 127u) << _18295))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22098 = _7867 * float2(cbFI_DisplaySize);
                }
                _22097 = _22098;
            }
            uint2 _7458 = uint2(clamp(round(_22097 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7460 = _7458.x;
            uint _7467 = _7458.y;
            _22099 = float4(float(_7460 & 255u), float((_7460 >> 8u) | ((_7467 & 15u) << 4u)), float(_7467 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22100;
            if (_6740 == 17u)
            {
                _22100 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5383, 0)).x != 0u), _5827, 0.0f, 1.0f);
            }
            else
            {
                _22100 = float4(_22061, 1.0f);
            }
            _22099 = _22100;
        }
        rw_output[_4868] = _22099.xyz;
        if (_7050)
        {
            uint _18340 = uint((_4868.y * cbFI_DisplaySize.x) + _4868.x) * 2u;
            rw_nfru_select.Store<uint>(_18340 * 4 + 0, spvPackHalf2x16(_22099.xy));
            rw_nfru_select.Store<uint>((_18340 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22099.z, (_21933 || (_6740 != 0u)) ? 2.0f : _22157)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7525 = ((uint(_4868.y) * uint(cbFI_DisplaySize.x)) + uint(_4868.x)) * 6u;
            uint _18366 = spvPackHalf2x16(clamp(_8571.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7525 * 4 + 0, (((_18366 & 32767u) >> 4u) | ((((_18366 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8571.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18401 = spvPackHalf2x16(clamp(_8579.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7525 + 1u) * 4 + 0, (((_18401 & 32767u) >> 4u) | ((((_18401 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8579.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18436 = spvPackHalf2x16(clamp(_8587.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7525 + 2u) * 4 + 0, (((_18436 & 32767u) >> 4u) | ((((_18436 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8587.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18471 = spvPackHalf2x16(clamp(_8595.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7525 + 3u) * 4 + 0, (((_18471 & 32767u) >> 4u) | ((((_18471 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8595.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _18498 = r_current_interpolation_source.Load(int3(_4868, 0));
            uint _18512 = spvPackHalf2x16(clamp(_18498.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7525 + 4u) * 4 + 0, (((_18512 & 32767u) >> 4u) | ((((_18512 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_18498.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _22176;
            if (_21933 || (_6740 != 0u))
            {
                _22176 = 4294967295u;
            }
            else
            {
                uint _18547 = spvPackHalf2x16(clamp(_22099.xy, 0.0f.xx, 65000.0f.xx));
                _22176 = (((_18547 & 32767u) >> 4u) | ((((_18547 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22099.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7525 + 5u) * 4 + 0, _22176);
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
