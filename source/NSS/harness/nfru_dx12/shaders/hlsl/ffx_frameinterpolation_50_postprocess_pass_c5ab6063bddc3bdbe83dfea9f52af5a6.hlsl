static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19634;

static const int2 _1243[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1252[5] = { 2, 4, 7, 11, 16 };
static const float3 _4633[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4934 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4934.x >= cbFI_DisplaySize.x, _4934.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4934] = float4(r_present_backbuffer.Load(int3(_4934, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7787 = cbFI_DisplaySize - int2(1, 1);
                int2 _7788 = clamp(_4934, int2(0, 0), _7787);
                uint _7798 = uint((_7788.y * cbFI_DisplaySize.x) + _7788.x) * 2u;
                uint _7801 = rw_nfru_select.Load<uint>(_7798 * 4 + 0);
                float2 _7802 = spvUnpackHalf2x16(_7801);
                uint _7806 = rw_nfru_select.Load<uint>((_7798 + 1u) * 4 + 0);
                float2 _7807 = spvUnpackHalf2x16(_7806);
                float _7808 = _7802.x;
                float _7810 = _7807.x;
                if (_7807.y > 1.5f)
                {
                    rw_output[_4934] = float4(_7808, _7802.y, _7810, 1.0f).xyz;
                    break;
                }
                int _23253;
                float _23254;
                float3 _23255;
                float _23256;
                float _23257;
                _23257 = 0.0f;
                _23256 = 0.0f;
                _23255 = 0.0f.xxx;
                _23254 = 0.0f;
                _23253 = -2;
                float3 _23260;
                float _23261;
                float _23262;
                float _23263;
                for (; _23253 <= 2; _23257 = _23263, _23256 = _23262, _23255 = _23260, _23254 = _23261, _23253++)
                {
                    _23263 = _23257;
                    _23262 = _23256;
                    _23261 = _23254;
                    _23260 = _23255;
                    for (int _23258 = -2; _23258 <= 2; )
                    {
                        float _7704 = float((_23258 * _23258) + (_23253 * _23253));
                        float _7709 = exp(_7704 * (-0.319999992847442626953125f));
                        int2 _7714 = int2(_23258, _23253);
                        int2 _7824 = clamp(_4934 + (_7714 * int2(2, 2)), int2(0, 0), _7787);
                        uint _7834 = uint((_7824.y * cbFI_DisplaySize.x) + _7824.x) * 2u;
                        float _7731 = exp(_7704 * (-0.5f));
                        int2 _7856 = clamp(_4934 + (_7714 * int2(6, 6)), int2(0, 0), _7787);
                        _23263 += _7731;
                        _23262 += (_7731 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7856.y * cbFI_DisplaySize.x) + _7856.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23261 += _7709;
                        _23260 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7834 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7834 + 1u) * 4 + 0)).x, _19634).xyz * _7709);
                        _23258++;
                        continue;
                    }
                }
                float3 _7761 = _23255 / _23254.xxx;
                rw_output[_4934] = float4(_7761 + ((float4(_7808, _7802.y, _7810, _7807.y).xyz - _7761) * clamp(_23256 / _23257, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5433 = (float2(_4934) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5435 = float2(cbFI_MvDepthLaneSize);
        int2 _5444 = int2(floor(_5433 * _5435));
        int2 _5449 = int2(floor(_5433 * float2(cbFI_FlowLaneSize)));
        float4 _7927 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5433 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7933 = r_warped_filled_flow_tm1.Load(int3(_5449, 0)).xy;
        float2 _7939 = r_warped_filled_motion_tp1.Load(int3(_5444, 0)).xy;
        bool _7961 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19635;
        if (_7961)
        {
            float _7974 = ((2.0f * _5433.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19635 = float2(atan(_7974) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5433.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7974 * _7974))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19635 = _5433;
        }
        bool _5470 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19656;
        bool _19798;
        int2 _19879;
        float3 _22371;
        if (_5470)
        {
            float _19637;
            float _19639;
            _19639 = 2.0f;
            _19637 = -1.0f;
            uint _5031[9];
            float _23264;
            float _23267;
            for (int _19636 = 0; _19636 < 9; _19639 = _23267, _19637 = _23264, _19636++)
            {
                _5031[_19636] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5444 + int2((_19636 % 3) - 1, (_19636 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_5031[_19636] != 0u)
                {
                    float _23248;
                    if (_5031[_19636] == 0u)
                    {
                        _23248 = -1.0f;
                    }
                    else
                    {
                        _23248 = float((_5031[_19636] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23267 = min(_19639, _23248);
                    _23264 = max(_19637, _23248);
                }
                else
                {
                    _23267 = _19639;
                    _23264 = _19637;
                }
            }
            float _5516 = float(_19637 >= 0.0f);
            float3 _19177 = 0.0f.xxx;
            _19177.y = _5516;
            float2 _19657;
            bool _19799;
            int2 _19880;
            float3 _22372;
            if ((_19637 - _19639) > 0.0199999995529651641845703125f)
            {
                float _19645;
                int2 _19646;
                float2 _19647;
                int2 _19649;
                float2 _19655;
                _19655 = _7939;
                _19649 = _5444;
                _19647 = _7939;
                _19646 = _5444;
                _19645 = -1.0f;
                float _23272;
                int2 _23276;
                float2 _23287;
                int2 _23298;
                float2 _23331;
                float _23456;
                int _19644 = 0;
                float _23229 = 1000000000.0f;
                for (; _19644 < 9; _23229 = _23456, _19655 = _23331, _19649 = _23298, _19647 = _23287, _19646 = _23276, _19645 = _23272, _19644++)
                {
                    if (_5031[_19644] == 0u)
                    {
                        _23456 = _23229;
                        _23331 = _19655;
                        _23298 = _19649;
                        _23287 = _19647;
                        _23276 = _19646;
                        _23272 = _19645;
                        continue;
                    }
                    int2 _5551 = clamp(_5444 + int2((_19644 % 3) - 1, (_19644 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8049 = _5031[_19644] & 2147483647u;
                    uint _8081 = uint(max((int((_8049 >> 16u) & 15u) - 6), 0));
                    float2 _5557 = (float2(float((1 - (2 * int((_8049 >> 15u) & 1u))) * int(((_8049 >> uint(7)) & 127u) << _8081)), float((1 - (2 * int((_8049 >> 14u) & 1u))) * int((_8049 & 127u) << _8081))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23215;
                    if (_5031[_19644] == 0u)
                    {
                        _23215 = -1.0f;
                    }
                    else
                    {
                        _23215 = float((_5031[_19644] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5562 = _23215 - 0.100000001490116119384765625f;
                    float2 _23216;
                    if (_7961)
                    {
                        float2 _8158 = clamp((((_19635 + (_5557 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8161 = tan(_8158.x);
                        _23216 = (float2(_8161 / cbFI_DeviceToViewDepth.z, (tan(_8158.y) * sqrt(1.0f + (_8161 * _8161))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23216 = _19635 + (_5557 * cbFI_Timestep);
                    }
                    float _5569 = cbFI_Timestep - 1.0f;
                    float2 _23217;
                    if (_7961)
                    {
                        float2 _8229 = clamp((((_19635 + (_5557 * _5569)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8232 = tan(_8229.x);
                        _23217 = (float2(_8232 / cbFI_DeviceToViewDepth.z, (tan(_8229.y) * sqrt(1.0f + (_8232 * _8232))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23217 = _19635 + (_5557 * _5569);
                    }
                    bool _8265 = all(bool2(_23216.x > 0.0f.xx.x, _23216.y > 0.0f.xx.y));
                    bool _8271;
                    if (_8265)
                    {
                        _8271 = all(bool2(_23216.x < 1.0f.xx.x, _23216.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8271 = _8265;
                    }
                    float _23220;
                    if (_8271)
                    {
                        uint _8278_dummy_parameter;
                        _23220 = max((_5562 - (log((r_depth_tm1.Load(int3(int2(floor(_23216 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8278_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23220 = 0.0f;
                    }
                    bool _8308 = all(bool2(_23217.x > 0.0f.xx.x, _23217.y > 0.0f.xx.y));
                    bool _8314;
                    if (_8308)
                    {
                        _8314 = all(bool2(_23217.x < 1.0f.xx.x, _23217.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8314 = _8308;
                    }
                    float _23221;
                    if (_8314)
                    {
                        uint _8321_dummy_parameter;
                        _23221 = _23220 + max((_5562 - (log((r_depth_tp1.Load(int3(int2(floor(_23217 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8321_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23221 = _23220;
                    }
                    float _23273;
                    int2 _23277;
                    float2 _23288;
                    int2 _23299;
                    float2 _23332;
                    float _23457;
                    if (_23221 == 0.0f)
                    {
                        bool _5604 = _5562 > _19645;
                        bool2 _23465 = _5604.xx;
                        _23457 = _23229;
                        _23332 = float2(_23465.x ? _5557.x : _19655.x, _23465.y ? _5557.y : _19655.y);
                        _23299 = int2(_23465.x ? _5551.x : _19649.x, _23465.y ? _5551.y : _19649.y);
                        _23288 = _19647;
                        _23277 = _19646;
                        _23273 = _5604 ? _5562 : _19645;
                    }
                    else
                    {
                        bool _5613 = _23221 < _23229;
                        bool2 _23461 = _5613.xx;
                        _23457 = _5613 ? _23221 : _23229;
                        _23332 = _19655;
                        _23299 = _19649;
                        _23288 = float2(_23461.x ? _5557.x : _19647.x, _23461.y ? _5557.y : _19647.y);
                        _23277 = int2(_23461.x ? _5551.x : _19646.x, _23461.y ? _5551.y : _19646.y);
                        _23273 = _19645;
                    }
                    _23456 = _23457;
                    _23331 = _23332;
                    _23298 = _23299;
                    _23287 = _23288;
                    _23276 = _23277;
                    _23272 = _23273;
                }
                bool _5625 = _19645 < 0.0f;
                bool2 _23471 = _5625.xx;
                int2 _23474 = int2(_23471.x ? _19646.x : _19649.x, _23471.y ? _19646.y : _19649.y);
                _22372 = float3(1.0f, _5516, float(any(bool2(_23474.x != _5444.x, _23474.y != _5444.y))));
                _19880 = _23474;
                _19799 = _5625 ? false : true;
                _19657 = float2(_23471.x ? _19647.x : _19655.x, _23471.y ? _19647.y : _19655.y);
            }
            else
            {
                _22372 = _19177;
                _19880 = _5444;
                _19799 = false;
                _19657 = _7939;
            }
            _22371 = _22372;
            _19879 = _19880;
            _19798 = _19799;
            _19656 = _19657;
        }
        else
        {
            _22371 = 0.0f.xxx;
            _19879 = _5444;
            _19798 = false;
            _19656 = _7939;
        }
        float2 _19658;
        if (_7961)
        {
            float2 _8386 = clamp((((_19635 + (_19656 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8389 = tan(_8386.x);
            _19658 = (float2(_8389 / cbFI_DeviceToViewDepth.z, (tan(_8386.y) * sqrt(1.0f + (_8389 * _8389))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19658 = _19635 + (_19656 * cbFI_Timestep);
        }
        float _5648 = cbFI_Timestep - 1.0f;
        float2 _19660;
        if (_7961)
        {
            float2 _8457 = clamp((((_19635 + (_19656 * _5648)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8460 = tan(_8457.x);
            _19660 = (float2(_8460 / cbFI_DeviceToViewDepth.z, (tan(_8457.y) * sqrt(1.0f + (_8460 * _8460))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19660 = _19635 + (_19656 * _5648);
        }
        float _5653 = -cbFI_Timestep;
        float2 _19661;
        if (_7961)
        {
            float2 _8528 = clamp((((_19635 + (_7933 * _5653)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8531 = tan(_8528.x);
            _19661 = (float2(_8531 / cbFI_DeviceToViewDepth.z, (tan(_8528.y) * sqrt(1.0f + (_8531 * _8531))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19661 = _19635 + (_7933 * _5653);
        }
        float _5658 = 1.0f - cbFI_Timestep;
        float2 _19662;
        if (_7961)
        {
            float2 _8599 = clamp((((_19635 + (_7933 * _5658)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8602 = tan(_8599.x);
            _19662 = (float2(_8602 / cbFI_DeviceToViewDepth.z, (tan(_8599.y) * sqrt(1.0f + (_8602 * _8602))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19662 = _19635 + (_7933 * _5658);
        }
        float4 _8637 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19658, 0.0f);
        float3 _8638 = _8637.xyz;
        float4 _8645 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19660, 0.0f);
        float3 _8646 = _8645.xyz;
        float4 _8653 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19661, 0.0f);
        float3 _8654 = _8653.xyz;
        float4 _8661 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19662, 0.0f);
        float3 _8662 = _8661.xyz;
        float4 _8676 = exp(_7927 - max(max(max(_7927.x, _7927.y), _7927.z), _7927.w).xxxx);
        float4 _8683 = _8676 / (dot(_8676, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5674 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19869;
        float _21177;
        if (_5674)
        {
            float2 _5680 = 0.5f.xx / _5435;
            float _5683 = _5680.x;
            float _5684 = -_5683;
            float _5686 = _5680.y;
            float _5687 = -_5686;
            float2 _5689 = _5433 + float2(_5684, _5687);
            float2 _5691 = float2(cbFI_DisplaySize);
            bool _19679;
            do
            {
                bool _8763 = all(bool2(_5689.x > 0.0f.xx.x, _5689.y > 0.0f.xx.y));
                bool _8769;
                if (_8763)
                {
                    _8769 = all(bool2(_5689.x < 1.0f.xx.x, _5689.y < 1.0f.xx.y));
                }
                else
                {
                    _8769 = _8763;
                }
                if (!_8769)
                {
                    _19679 = false;
                    break;
                }
                uint _8776_dummy_parameter;
                float4x4 _19677;
                do
                {
                    float4x4 _8790;
                    bool _19676;
                    do
                    {
                        _8790 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19676 = false;
                            break;
                        }
                        uint _8824 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8824 + 32u) * 4 + 0) != 1u)
                        {
                            _19676 = false;
                            break;
                        }
                        uint _19673;
                        _19673 = 0u;
                        for (; _19673 < 4u; _19673++)
                        {
                            for (uint _19674 = 0u; _19674 < 4u; )
                            {
                                _8790[_19673][_19674] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8824 + (_19673 * 4u)) + _19674) * 4 + 0));
                                _19674++;
                                continue;
                            }
                        }
                        _19676 = true;
                        break;
                    } while(false);
                    if (_19676)
                    {
                        _19677 = _8790;
                        break;
                    }
                    _19677 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19678;
                do
                {
                    float _8901 = _5689.x;
                    float _8904 = 1.0f - _5689.y;
                    float4 _8915 = mul(float4((float2(_8901, _8904) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5689 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8776_dummy_parameter))))), 0)).x, 1.0f), _19677);
                    float _8917 = _8915.w;
                    if (!(_8917 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19678 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8930 = ((_8915.xy / _8917.xx) + 1.0f.xx) * 0.5f;
                    _19678 = float2(_8930.x - _8901, _8904 - _8930.y);
                    break;
                } while(false);
                float2 _8727 = abs(_19678);
                if (any(bool2(_8727.x > 100000.0f.xx.x, _8727.y > 100000.0f.xx.y)))
                {
                    _19679 = false;
                    break;
                }
                float _8735 = length(_19678 * _5691);
                uint _8950_dummy_parameter;
                bool _8749 = _8735 > ((8.0f * _5691.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8756;
                if (_8749)
                {
                    _8756 = length((r_motion_tp1.Load(int3(int2(floor(_5689 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8950_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5691) < (0.20000000298023223876953125f * _8735);
                }
                else
                {
                    _8756 = _8749;
                }
                _19679 = _8756;
                break;
            } while(false);
            float2 _5701 = _5433 + float2(_5683, _5687);
            bool _19686;
            do
            {
                bool _9036 = all(bool2(_5701.x > 0.0f.xx.x, _5701.y > 0.0f.xx.y));
                bool _9042;
                if (_9036)
                {
                    _9042 = all(bool2(_5701.x < 1.0f.xx.x, _5701.y < 1.0f.xx.y));
                }
                else
                {
                    _9042 = _9036;
                }
                if (!_9042)
                {
                    _19686 = false;
                    break;
                }
                uint _9049_dummy_parameter;
                float4x4 _19684;
                do
                {
                    float4x4 _9063;
                    bool _19683;
                    do
                    {
                        _9063 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19683 = false;
                            break;
                        }
                        uint _9097 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9097 + 32u) * 4 + 0) != 1u)
                        {
                            _19683 = false;
                            break;
                        }
                        uint _19680;
                        _19680 = 0u;
                        for (; _19680 < 4u; _19680++)
                        {
                            for (uint _19681 = 0u; _19681 < 4u; )
                            {
                                _9063[_19680][_19681] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9097 + (_19680 * 4u)) + _19681) * 4 + 0));
                                _19681++;
                                continue;
                            }
                        }
                        _19683 = true;
                        break;
                    } while(false);
                    if (_19683)
                    {
                        _19684 = _9063;
                        break;
                    }
                    _19684 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19685;
                do
                {
                    float _9174 = _5701.x;
                    float _9177 = 1.0f - _5701.y;
                    float4 _9188 = mul(float4((float2(_9174, _9177) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5701 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9049_dummy_parameter))))), 0)).x, 1.0f), _19684);
                    float _9190 = _9188.w;
                    if (!(_9190 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19685 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9203 = ((_9188.xy / _9190.xx) + 1.0f.xx) * 0.5f;
                    _19685 = float2(_9203.x - _9174, _9177 - _9203.y);
                    break;
                } while(false);
                float2 _9000 = abs(_19685);
                if (any(bool2(_9000.x > 100000.0f.xx.x, _9000.y > 100000.0f.xx.y)))
                {
                    _19686 = false;
                    break;
                }
                float _9008 = length(_19685 * _5691);
                uint _9223_dummy_parameter;
                bool _9022 = _9008 > ((8.0f * _5691.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9029;
                if (_9022)
                {
                    _9029 = length((r_motion_tp1.Load(int3(int2(floor(_5701 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9223_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5691) < (0.20000000298023223876953125f * _9008);
                }
                else
                {
                    _9029 = _9022;
                }
                _19686 = _9029;
                break;
            } while(false);
            float2 _5714 = _5433 + float2(_5684, _5686);
            bool _19693;
            do
            {
                bool _9309 = all(bool2(_5714.x > 0.0f.xx.x, _5714.y > 0.0f.xx.y));
                bool _9315;
                if (_9309)
                {
                    _9315 = all(bool2(_5714.x < 1.0f.xx.x, _5714.y < 1.0f.xx.y));
                }
                else
                {
                    _9315 = _9309;
                }
                if (!_9315)
                {
                    _19693 = false;
                    break;
                }
                uint _9322_dummy_parameter;
                float4x4 _19691;
                do
                {
                    float4x4 _9336;
                    bool _19690;
                    do
                    {
                        _9336 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19690 = false;
                            break;
                        }
                        uint _9370 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9370 + 32u) * 4 + 0) != 1u)
                        {
                            _19690 = false;
                            break;
                        }
                        uint _19687;
                        _19687 = 0u;
                        for (; _19687 < 4u; _19687++)
                        {
                            for (uint _19688 = 0u; _19688 < 4u; )
                            {
                                _9336[_19687][_19688] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9370 + (_19687 * 4u)) + _19688) * 4 + 0));
                                _19688++;
                                continue;
                            }
                        }
                        _19690 = true;
                        break;
                    } while(false);
                    if (_19690)
                    {
                        _19691 = _9336;
                        break;
                    }
                    _19691 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19692;
                do
                {
                    float _9447 = _5714.x;
                    float _9450 = 1.0f - _5714.y;
                    float4 _9461 = mul(float4((float2(_9447, _9450) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5714 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9322_dummy_parameter))))), 0)).x, 1.0f), _19691);
                    float _9463 = _9461.w;
                    if (!(_9463 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19692 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9476 = ((_9461.xy / _9463.xx) + 1.0f.xx) * 0.5f;
                    _19692 = float2(_9476.x - _9447, _9450 - _9476.y);
                    break;
                } while(false);
                float2 _9273 = abs(_19692);
                if (any(bool2(_9273.x > 100000.0f.xx.x, _9273.y > 100000.0f.xx.y)))
                {
                    _19693 = false;
                    break;
                }
                float _9281 = length(_19692 * _5691);
                uint _9496_dummy_parameter;
                bool _9295 = _9281 > ((8.0f * _5691.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9302;
                if (_9295)
                {
                    _9302 = length((r_motion_tp1.Load(int3(int2(floor(_5714 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9496_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5691) < (0.20000000298023223876953125f * _9281);
                }
                else
                {
                    _9302 = _9295;
                }
                _19693 = _9302;
                break;
            } while(false);
            float2 _5726 = _5433 + _5680;
            bool _19700;
            do
            {
                bool _9582 = all(bool2(_5726.x > 0.0f.xx.x, _5726.y > 0.0f.xx.y));
                bool _9588;
                if (_9582)
                {
                    _9588 = all(bool2(_5726.x < 1.0f.xx.x, _5726.y < 1.0f.xx.y));
                }
                else
                {
                    _9588 = _9582;
                }
                if (!_9588)
                {
                    _19700 = false;
                    break;
                }
                uint _9595_dummy_parameter;
                float4x4 _19698;
                do
                {
                    float4x4 _9609;
                    bool _19697;
                    do
                    {
                        _9609 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19697 = false;
                            break;
                        }
                        uint _9643 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9643 + 32u) * 4 + 0) != 1u)
                        {
                            _19697 = false;
                            break;
                        }
                        uint _19694;
                        _19694 = 0u;
                        for (; _19694 < 4u; _19694++)
                        {
                            for (uint _19695 = 0u; _19695 < 4u; )
                            {
                                _9609[_19694][_19695] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9643 + (_19694 * 4u)) + _19695) * 4 + 0));
                                _19695++;
                                continue;
                            }
                        }
                        _19697 = true;
                        break;
                    } while(false);
                    if (_19697)
                    {
                        _19698 = _9609;
                        break;
                    }
                    _19698 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19699;
                do
                {
                    float _9720 = _5726.x;
                    float _9723 = 1.0f - _5726.y;
                    float4 _9734 = mul(float4((float2(_9720, _9723) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5726 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9595_dummy_parameter))))), 0)).x, 1.0f), _19698);
                    float _9736 = _9734.w;
                    if (!(_9736 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19699 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9749 = ((_9734.xy / _9736.xx) + 1.0f.xx) * 0.5f;
                    _19699 = float2(_9749.x - _9720, _9723 - _9749.y);
                    break;
                } while(false);
                float2 _9546 = abs(_19699);
                if (any(bool2(_9546.x > 100000.0f.xx.x, _9546.y > 100000.0f.xx.y)))
                {
                    _19700 = false;
                    break;
                }
                float _9554 = length(_19699 * _5691);
                uint _9769_dummy_parameter;
                bool _9568 = _9554 > ((8.0f * _5691.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9575;
                if (_9568)
                {
                    _9575 = length((r_motion_tp1.Load(int3(int2(floor(_5726 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9769_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5691) < (0.20000000298023223876953125f * _9554);
                }
                else
                {
                    _9575 = _9568;
                }
                _19700 = _9575;
                break;
            } while(false);
            float _5732 = 0.25f * (((float(_19679) + float(_19686)) + float(_19693)) + float(_19700));
            float4 _19870;
            if (_5732 < 1.0f)
            {
                bool _19707;
                do
                {
                    bool _9855 = all(bool2(_19658.x > 0.0f.xx.x, _19658.y > 0.0f.xx.y));
                    bool _9861;
                    if (_9855)
                    {
                        _9861 = all(bool2(_19658.x < 1.0f.xx.x, _19658.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9861 = _9855;
                    }
                    if (!_9861)
                    {
                        _19707 = false;
                        break;
                    }
                    uint _9868_dummy_parameter;
                    float4x4 _19705;
                    do
                    {
                        float4x4 _9882;
                        bool _19704;
                        do
                        {
                            _9882 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19704 = false;
                                break;
                            }
                            uint _9916 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9916 + 32u) * 4 + 0) != 1u)
                            {
                                _19704 = false;
                                break;
                            }
                            uint _19701;
                            _19701 = 0u;
                            for (; _19701 < 4u; _19701++)
                            {
                                for (uint _19702 = 0u; _19702 < 4u; )
                                {
                                    _9882[_19701][_19702] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9916 + (_19701 * 4u)) + _19702) * 4 + 0));
                                    _19702++;
                                    continue;
                                }
                            }
                            _19704 = true;
                            break;
                        } while(false);
                        if (_19704)
                        {
                            _19705 = _9882;
                            break;
                        }
                        _19705 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19706;
                    do
                    {
                        float _9996 = 1.0f - _19658.y;
                        float4 _10007 = mul(float4((float2(_19658.x, _9996) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19658 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9868_dummy_parameter))))), 0)).x, 1.0f), _19705);
                        float _10009 = _10007.w;
                        if (!(_10009 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19706 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10022 = ((_10007.xy / _10009.xx) + 1.0f.xx) * 0.5f;
                        _19706 = float2(_10022.x - _19658.x, _9996 - _10022.y);
                        break;
                    } while(false);
                    float2 _9819 = abs(_19706);
                    if (any(bool2(_9819.x > 100000.0f.xx.x, _9819.y > 100000.0f.xx.y)))
                    {
                        _19707 = false;
                        break;
                    }
                    float _9827 = length(_19706 * _5691);
                    uint _10042_dummy_parameter;
                    bool _9841 = _9827 > ((8.0f * _5691.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9848;
                    if (_9841)
                    {
                        _9848 = length((r_motion_tp1.Load(int3(int2(floor(_19658 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10042_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5691) < (0.20000000298023223876953125f * _9827);
                    }
                    else
                    {
                        _9848 = _9841;
                    }
                    _19707 = _9848;
                    break;
                } while(false);
                bool _19714;
                do
                {
                    bool _10128 = all(bool2(_19660.x > 0.0f.xx.x, _19660.y > 0.0f.xx.y));
                    bool _10134;
                    if (_10128)
                    {
                        _10134 = all(bool2(_19660.x < 1.0f.xx.x, _19660.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10134 = _10128;
                    }
                    if (!_10134)
                    {
                        _19714 = false;
                        break;
                    }
                    uint _10141_dummy_parameter;
                    float4x4 _19712;
                    do
                    {
                        float4x4 _10155;
                        bool _19711;
                        do
                        {
                            _10155 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19711 = false;
                                break;
                            }
                            uint _10189 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10189 + 32u) * 4 + 0) != 1u)
                            {
                                _19711 = false;
                                break;
                            }
                            uint _19708;
                            _19708 = 0u;
                            for (; _19708 < 4u; _19708++)
                            {
                                for (uint _19709 = 0u; _19709 < 4u; )
                                {
                                    _10155[_19708][_19709] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10189 + (_19708 * 4u)) + _19709) * 4 + 0));
                                    _19709++;
                                    continue;
                                }
                            }
                            _19711 = true;
                            break;
                        } while(false);
                        if (_19711)
                        {
                            _19712 = _10155;
                            break;
                        }
                        _19712 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19713;
                    do
                    {
                        float _10269 = 1.0f - _19660.y;
                        float4 _10280 = mul(float4((float2(_19660.x, _10269) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19660 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10141_dummy_parameter))))), 0)).x, 1.0f), _19712);
                        float _10282 = _10280.w;
                        if (!(_10282 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19713 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10295 = ((_10280.xy / _10282.xx) + 1.0f.xx) * 0.5f;
                        _19713 = float2(_10295.x - _19660.x, _10269 - _10295.y);
                        break;
                    } while(false);
                    float2 _10092 = abs(_19713);
                    if (any(bool2(_10092.x > 100000.0f.xx.x, _10092.y > 100000.0f.xx.y)))
                    {
                        _19714 = false;
                        break;
                    }
                    float _10100 = length(_19713 * _5691);
                    uint _10315_dummy_parameter;
                    bool _10114 = _10100 > ((8.0f * _5691.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10121;
                    if (_10114)
                    {
                        _10121 = length((r_motion_tp1.Load(int3(int2(floor(_19660 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10315_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5691) < (0.20000000298023223876953125f * _10100);
                    }
                    else
                    {
                        _10121 = _10114;
                    }
                    _19714 = _10121;
                    break;
                } while(false);
                bool _19721;
                do
                {
                    bool _10401 = all(bool2(_19661.x > 0.0f.xx.x, _19661.y > 0.0f.xx.y));
                    bool _10407;
                    if (_10401)
                    {
                        _10407 = all(bool2(_19661.x < 1.0f.xx.x, _19661.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10407 = _10401;
                    }
                    if (!_10407)
                    {
                        _19721 = false;
                        break;
                    }
                    uint _10414_dummy_parameter;
                    float4x4 _19719;
                    do
                    {
                        float4x4 _10428;
                        bool _19718;
                        do
                        {
                            _10428 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19718 = false;
                                break;
                            }
                            uint _10462 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10462 + 32u) * 4 + 0) != 1u)
                            {
                                _19718 = false;
                                break;
                            }
                            uint _19715;
                            _19715 = 0u;
                            for (; _19715 < 4u; _19715++)
                            {
                                for (uint _19716 = 0u; _19716 < 4u; )
                                {
                                    _10428[_19715][_19716] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10462 + (_19715 * 4u)) + _19716) * 4 + 0));
                                    _19716++;
                                    continue;
                                }
                            }
                            _19718 = true;
                            break;
                        } while(false);
                        if (_19718)
                        {
                            _19719 = _10428;
                            break;
                        }
                        _19719 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19720;
                    do
                    {
                        float _10542 = 1.0f - _19661.y;
                        float4 _10553 = mul(float4((float2(_19661.x, _10542) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19661 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10414_dummy_parameter))))), 0)).x, 1.0f), _19719);
                        float _10555 = _10553.w;
                        if (!(_10555 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19720 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10568 = ((_10553.xy / _10555.xx) + 1.0f.xx) * 0.5f;
                        _19720 = float2(_10568.x - _19661.x, _10542 - _10568.y);
                        break;
                    } while(false);
                    float2 _10365 = abs(_19720);
                    if (any(bool2(_10365.x > 100000.0f.xx.x, _10365.y > 100000.0f.xx.y)))
                    {
                        _19721 = false;
                        break;
                    }
                    float _10373 = length(_19720 * _5691);
                    uint _10588_dummy_parameter;
                    bool _10387 = _10373 > ((8.0f * _5691.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10394;
                    if (_10387)
                    {
                        _10394 = length((r_motion_tp1.Load(int3(int2(floor(_19661 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10588_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5691) < (0.20000000298023223876953125f * _10373);
                    }
                    else
                    {
                        _10394 = _10387;
                    }
                    _19721 = _10394;
                    break;
                } while(false);
                bool _19728;
                do
                {
                    bool _10674 = all(bool2(_19662.x > 0.0f.xx.x, _19662.y > 0.0f.xx.y));
                    bool _10680;
                    if (_10674)
                    {
                        _10680 = all(bool2(_19662.x < 1.0f.xx.x, _19662.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10680 = _10674;
                    }
                    if (!_10680)
                    {
                        _19728 = false;
                        break;
                    }
                    uint _10687_dummy_parameter;
                    float4x4 _19726;
                    do
                    {
                        float4x4 _10701;
                        bool _19725;
                        do
                        {
                            _10701 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19725 = false;
                                break;
                            }
                            uint _10735 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10735 + 32u) * 4 + 0) != 1u)
                            {
                                _19725 = false;
                                break;
                            }
                            uint _19722;
                            _19722 = 0u;
                            for (; _19722 < 4u; _19722++)
                            {
                                for (uint _19723 = 0u; _19723 < 4u; )
                                {
                                    _10701[_19722][_19723] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10735 + (_19722 * 4u)) + _19723) * 4 + 0));
                                    _19723++;
                                    continue;
                                }
                            }
                            _19725 = true;
                            break;
                        } while(false);
                        if (_19725)
                        {
                            _19726 = _10701;
                            break;
                        }
                        _19726 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19727;
                    do
                    {
                        float _10815 = 1.0f - _19662.y;
                        float4 _10826 = mul(float4((float2(_19662.x, _10815) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19662 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10687_dummy_parameter))))), 0)).x, 1.0f), _19726);
                        float _10828 = _10826.w;
                        if (!(_10828 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19727 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10841 = ((_10826.xy / _10828.xx) + 1.0f.xx) * 0.5f;
                        _19727 = float2(_10841.x - _19662.x, _10815 - _10841.y);
                        break;
                    } while(false);
                    float2 _10638 = abs(_19727);
                    if (any(bool2(_10638.x > 100000.0f.xx.x, _10638.y > 100000.0f.xx.y)))
                    {
                        _19728 = false;
                        break;
                    }
                    float _10646 = length(_19727 * _5691);
                    uint _10861_dummy_parameter;
                    bool _10660 = _10646 > ((8.0f * _5691.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10667;
                    if (_10660)
                    {
                        _10667 = length((r_motion_tp1.Load(int3(int2(floor(_19662 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10861_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5691) < (0.20000000298023223876953125f * _10646);
                    }
                    else
                    {
                        _10667 = _10660;
                    }
                    _19728 = _10667;
                    break;
                } while(false);
                float4 _5759 = _8683 * float4(_19707 ? 0.0f : 1.0f, _19714 ? 0.0f : 1.0f, _19721 ? 0.0f : 1.0f, _19728 ? 0.0f : 1.0f);
                float _5761 = dot(_5759, 1.0f.xxxx);
                float4 _19871;
                if (_5761 > 0.001000000047497451305389404296875f)
                {
                    _19871 = _5759 / _5761.xxxx;
                }
                else
                {
                    _19871 = _8683;
                }
                _19870 = _19871;
            }
            else
            {
                _19870 = _8683;
            }
            _21177 = _5732;
            _19869 = _19870;
        }
        else
        {
            _21177 = 0.0f;
            _19869 = _8683;
        }
        bool _5778 = _5470 && (!_19798);
        bool _5787;
        if (_5778)
        {
            _5787 = (_19869.z + _19869.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5787 = _5778;
        }
        bool _5798;
        if (_5787)
        {
            _5798 = length((_19661 - _19658) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5798 = _5787;
        }
        bool _19958;
        if (_5798)
        {
            uint4 _10890 = r_warped_motion_qdata_tp1.Load(int3(_19879, 0));
            uint _10891 = _10890.x;
            bool _19961;
            if (_10891 != 0u)
            {
                float _19947;
                if (_10891 == 0u)
                {
                    _19947 = -1.0f;
                }
                else
                {
                    _19947 = float((_10891 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5808 = _19947 - 0.12000000476837158203125f;
                bool _10910 = all(bool2(_19661.x > 0.0f.xx.x, _19661.y > 0.0f.xx.y));
                bool _10916;
                if (_10910)
                {
                    _10916 = all(bool2(_19661.x < 1.0f.xx.x, _19661.y < 1.0f.xx.y));
                }
                else
                {
                    _10916 = _10910;
                }
                bool _5818;
                if (_10916)
                {
                    uint _10923_dummy_parameter;
                    _5818 = (log((r_depth_tm1.Load(int3(int2(floor(_19661 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10923_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5808;
                }
                else
                {
                    _5818 = _10916;
                }
                bool _5832;
                if (!_5818)
                {
                    bool _10953 = all(bool2(_19662.x > 0.0f.xx.x, _19662.y > 0.0f.xx.y));
                    bool _10959;
                    if (_10953)
                    {
                        _10959 = all(bool2(_19662.x < 1.0f.xx.x, _19662.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10959 = _10953;
                    }
                    bool _5830;
                    if (_10959)
                    {
                        uint _10966_dummy_parameter;
                        _5830 = (log((r_depth_tp1.Load(int3(int2(floor(_19662 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10966_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5808;
                    }
                    else
                    {
                        _5830 = _10959;
                    }
                    _5832 = _5830;
                }
                else
                {
                    _5832 = _5818;
                }
                _19961 = _5832;
            }
            else
            {
                _19961 = false;
            }
            _19958 = _19961;
        }
        else
        {
            _19958 = false;
        }
        bool _5837 = _19798 || _19958;
        bool _5842;
        if (_5837)
        {
            bool _10996 = all(bool2(_19658.x > 0.0f.xx.x, _19658.y > 0.0f.xx.y));
            bool _11002;
            if (_10996)
            {
                _11002 = all(bool2(_19658.x < 1.0f.xx.x, _19658.y < 1.0f.xx.y));
            }
            else
            {
                _11002 = _10996;
            }
            _5842 = _11002;
        }
        else
        {
            _5842 = _5837;
        }
        bool _5847;
        if (_5842)
        {
            bool _11007 = all(bool2(_19660.x > 0.0f.xx.x, _19660.y > 0.0f.xx.y));
            bool _11013;
            if (_11007)
            {
                _11013 = all(bool2(_19660.x < 1.0f.xx.x, _19660.y < 1.0f.xx.y));
            }
            else
            {
                _11013 = _11007;
            }
            _5847 = _11013;
        }
        else
        {
            _5847 = _5842;
        }
        float4 _20081;
        if (_5847)
        {
            float _5853 = _19869.x + _19869.y;
            float _5858 = _19869.z + _19869.w;
            float _19976;
            if (_5853 > 0.001000000047497451305389404296875f)
            {
                _19976 = _19869.x / _5853;
            }
            else
            {
                _19976 = _5658;
            }
            _20081 = float4(_19869.x + (_5858 * _19976), _19869.y + (_5858 * (1.0f - _19976)), 0.0f, 0.0f);
        }
        else
        {
            _20081 = _19869;
        }
        bool _11041 = (cbFI_pad0 & 1024u) != 0u;
        bool _11017 = !_11041;
        bool _11018 = !_11017;
        bool _11035;
        if (_11018)
        {
            _11035 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19879.y * cbFI_MvDepthLaneSize.x) + _19879.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11035 = _11017;
        }
        bool _11067;
        if (_11018)
        {
            _11067 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5449.y * cbFI_FlowLaneSize.x) + _5449.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11067 = _11017;
        }
        float _5893 = float(_11067);
        bool _20102;
        float4 _20141;
        float3 _22068;
        if (_11041)
        {
            bool _5903;
            if (_11035)
            {
                _5903 = all(bool2(_19658.x > 0.0f.xx.x, _19658.y > 0.0f.xx.y));
            }
            else
            {
                _5903 = _11035;
            }
            bool _5909;
            if (_5903)
            {
                _5909 = all(bool2(_19658.x < 1.0f.xx.x, _19658.y < 1.0f.xx.y));
            }
            else
            {
                _5909 = _5903;
            }
            bool _5916;
            if (_11035)
            {
                _5916 = all(bool2(_19660.x > 0.0f.xx.x, _19660.y > 0.0f.xx.y));
            }
            else
            {
                _5916 = _11035;
            }
            bool _5922;
            if (_5916)
            {
                _5922 = all(bool2(_19660.x < 1.0f.xx.x, _19660.y < 1.0f.xx.y));
            }
            else
            {
                _5922 = _5916;
            }
            bool _5929;
            if (_11067)
            {
                _5929 = all(bool2(_19661.x > 0.0f.xx.x, _19661.y > 0.0f.xx.y));
            }
            else
            {
                _5929 = _11067;
            }
            bool _5935;
            if (_5929)
            {
                _5935 = all(bool2(_19661.x < 1.0f.xx.x, _19661.y < 1.0f.xx.y));
            }
            else
            {
                _5935 = _5929;
            }
            bool _5942;
            if (_11067)
            {
                _5942 = all(bool2(_19662.x > 0.0f.xx.x, _19662.y > 0.0f.xx.y));
            }
            else
            {
                _5942 = _11067;
            }
            bool _5948;
            if (_5942)
            {
                _5948 = all(bool2(_19662.x < 1.0f.xx.x, _19662.y < 1.0f.xx.y));
            }
            else
            {
                _5948 = _5942;
            }
            bool _5950 = !_11035;
            if (_5950)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11109;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11109);
                }
            }
            bool _5955 = !_11067;
            if (_5955)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11119;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11119);
                }
            }
            if (_11035 && _5955)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11129;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11129);
                }
            }
            if (_5950 && _11067)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11139;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11139);
                }
            }
            float _5974 = float(_5909);
            float _5976 = float(_5922);
            bool _5979 = _5935 && _5948;
            float _20010;
            if (_5979)
            {
                _20010 = 1.0f;
            }
            else
            {
                _20010 = (_5935 || _5948) ? 0.5f : 0.0f;
            }
            bool _20025;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5909)) && (!_5922))
            {
                bool _6009;
                if (_5979)
                {
                    float _20018;
                    do
                    {
                        bool _11223 = all(bool2(_19661.x > 0.0f.xx.x, _19661.y > 0.0f.xx.y));
                        bool _11229;
                        if (_11223)
                        {
                            _11229 = all(bool2(_19661.x < 1.0f.xx.x, _19661.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11229 = _11223;
                        }
                        bool _11160 = !_11229;
                        bool _11167;
                        if (!_11160)
                        {
                            bool _11234 = all(bool2(_19662.x > 0.0f.xx.x, _19662.y > 0.0f.xx.y));
                            bool _11240;
                            if (_11234)
                            {
                                _11240 = all(bool2(_19662.x < 1.0f.xx.x, _19662.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11240 = _11234;
                            }
                            _11167 = !_11240;
                        }
                        else
                        {
                            _11167 = _11160;
                        }
                        if (_11167)
                        {
                            _20018 = 0.0f;
                            break;
                        }
                        uint _11247_dummy_parameter;
                        uint _11263_dummy_parameter;
                        float4x4 _20017;
                        do
                        {
                            float4x4 _11277;
                            bool _20016;
                            do
                            {
                                _11277 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20016 = false;
                                    break;
                                }
                                uint _11311 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11311 + 32u) * 4 + 0) != 1u)
                                {
                                    _20016 = false;
                                    break;
                                }
                                uint _20013;
                                _20013 = 0u;
                                for (; _20013 < 4u; _20013++)
                                {
                                    for (uint _20014 = 0u; _20014 < 4u; )
                                    {
                                        _11277[_20013][_20014] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11311 + 16u) + (_20013 * 4u)) + _20014) * 4 + 0));
                                        _20014++;
                                        continue;
                                    }
                                }
                                _20016 = true;
                                break;
                            } while(false);
                            if (_20016)
                            {
                                _20017 = _11277;
                                break;
                            }
                            _20017 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11188 = mul(float4((float2(_19661.x, 1.0f - _19661.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19661 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11247_dummy_parameter))))), 0)).x, 1.0f), _20017);
                        float _11190 = _11188.w;
                        if (abs(_11190) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20018 = 0.0f;
                            break;
                        }
                        float _11201 = abs(cbFI_DeviceToViewDepth.y / ((_11188.z / _11190) - cbFI_DeviceToViewDepth.x));
                        float _11204 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19662 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11263_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20018 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11201 - _11204) / max(max(_11201, _11204), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _6009 = _20018 >= 0.5f;
                }
                else
                {
                    _6009 = _5979;
                }
                bool _6017;
                if (_6009)
                {
                    _6017 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _6017 = _6009;
                }
                bool _20026;
                if (_6017)
                {
                    uint _11415_dummy_parameter;
                    float4x4 _20023;
                    do
                    {
                        float4x4 _11429;
                        bool _20022;
                        do
                        {
                            _11429 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20022 = false;
                                break;
                            }
                            uint _11463 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11463 + 32u) * 4 + 0) != 1u)
                            {
                                _20022 = false;
                                break;
                            }
                            uint _20019;
                            _20019 = 0u;
                            for (; _20019 < 4u; _20019++)
                            {
                                for (uint _20020 = 0u; _20020 < 4u; )
                                {
                                    _11429[_20019][_20020] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11463 + 16u) + (_20019 * 4u)) + _20020) * 4 + 0));
                                    _20020++;
                                    continue;
                                }
                            }
                            _20022 = true;
                            break;
                        } while(false);
                        if (_20022)
                        {
                            _20023 = _11429;
                            break;
                        }
                        _20023 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20024;
                    do
                    {
                        float _11543 = 1.0f - _19661.y;
                        float4 _11554 = mul(float4((float2(_19661.x, _11543) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19661 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11415_dummy_parameter))))), 0)).x, 1.0f), _20023);
                        float _11556 = _11554.w;
                        if (!(_11556 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20024 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11569 = ((_11554.xy / _11556.xx) + 1.0f.xx) * 0.5f;
                        _20024 = float2(_11569.x - _19661.x, _11543 - _11569.y);
                        break;
                    } while(false);
                    float2 _6030 = float2(cbFI_DisplaySize);
                    _20026 = length(((_19661 + _20024) - _19662) * _6030) <= ((0.100000001490116119384765625f * length(_20024 * _6030)) + 8.0f);
                }
                else
                {
                    _20026 = _6009;
                }
                _20025 = _20026;
            }
            else
            {
                _20025 = true;
            }
            bool _6044 = !_20025;
            bool _23475 = _6044 ? false : _5948;
            bool _23476 = _6044 ? false : _5935;
            bool _20103;
            float4 _20142;
            if (!(((_5909 && _5922) && _23476) && _23475))
            {
                float4 _6066 = _20081 * float4(_5974, _5976, float(_23476), float(_23475));
                float _6068 = dot(_6066, 1.0f.xxxx);
                bool _6071 = !(_6068 > 0.0f);
                float4 _20143;
                if (!_6071)
                {
                    _20143 = _6066 / _6068.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11591;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11591);
                    }
                    _20143 = 0.0f.xxxx;
                }
                _20142 = _20143;
                _20103 = _6071;
            }
            else
            {
                _20142 = _20081;
                _20103 = false;
            }
            _22068 = float3(_5974, _5976, _20010);
            _20141 = _20142;
            _20102 = _20103;
        }
        else
        {
            _22068 = float3(float(_11035), _5893, 0.0f);
            _20141 = _20081;
            _20102 = false;
        }
        bool _6089 = !_20102;
        float4 _20234;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6089)
        {
            float _6096 = _20141.x + _20141.y;
            float4 _20235;
            if (_6096 > 0.001000000047497451305389404296875f)
            {
                _20235 = float4(_20141.x / _6096, _20141.y / _6096, 0.0f, 0.0f);
            }
            else
            {
                _20235 = float4(_5658, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20234 = _20235;
        }
        else
        {
            _20234 = _20141;
        }
        float4 _20411;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6089) && _11035)
        {
            float _20208;
            do
            {
                uint4 _11731 = r_warped_motion_qdata_tp1.Load(int3(_19879, 0));
                uint _11732 = _11731.x;
                if (_11732 != 0u)
                {
                    float _20207;
                    if (_11732 == 0u)
                    {
                        _20207 = -1.0f;
                    }
                    else
                    {
                        _20207 = float((_11732 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20208 = _20207;
                    break;
                }
                int _20190;
                uint _20191;
                _20191 = _11732;
                _20190 = -1;
                uint _20206;
                for (; _20190 <= 1; _20191 = _20206, _20190++)
                {
                    _20206 = _20191;
                    for (int _20204 = -1; _20204 <= 1; )
                    {
                        _20206 = max(_20206, r_warped_motion_qdata_tp1.Load(int3(clamp(_19879 + int2(_20204, _20190), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20204++;
                        continue;
                    }
                }
                if (_20191 != 0u)
                {
                    float _20203;
                    if (_20191 == 0u)
                    {
                        _20203 = -1.0f;
                    }
                    else
                    {
                        _20203 = float((_20191 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20208 = _20203;
                    break;
                }
                uint _20193;
                _20193 = 4294967295u;
                uint _23368;
                for (int _20192 = 0; _20192 < 8; _20193 = _23368, _20192++)
                {
                    int _20196 = 0;
                    for (;;)
                    {
                        if (_20196 < 5)
                        {
                            int2 _11682 = _19879 + (_1243[_20192] * _1252[_20196].xx);
                            bool _11685 = any(bool2(_11682.x < int2(0, 0).x, _11682.y < int2(0, 0).y));
                            bool _11693;
                            if (!_11685)
                            {
                                _11693 = any(bool2(_11682.x >= cbFI_MvDepthLaneSize.x, _11682.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11693 = _11685;
                            }
                            if (_11693)
                            {
                                _23368 = _20193;
                                break;
                            }
                            uint4 _11771 = r_warped_motion_qdata_tp1.Load(int3(_11682, 0));
                            uint _11772 = _11771.x;
                            if (_11772 != 0u)
                            {
                                _23368 = min(_20193, _11772);
                                break;
                            }
                            _20196++;
                            continue;
                        }
                        else
                        {
                            _23368 = _20193;
                            break;
                        }
                    }
                }
                float _20195;
                if (_20193 == 4294967295u)
                {
                    _20195 = -1.0f;
                }
                else
                {
                    float _20194;
                    if (_20193 == 0u)
                    {
                        _20194 = -1.0f;
                    }
                    else
                    {
                        _20194 = float((_20193 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20195 = _20194;
                }
                _20208 = _20195;
                break;
            } while(false);
            float _6132 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6135 = r_warped_motion_qdata_tp1.Load(int3(_19879, 0)).x == 0u;
            bool _6141;
            if (_6135)
            {
                bool _11797 = all(bool2(_19658.x > 0.0f.xx.x, _19658.y > 0.0f.xx.y));
                bool _11803;
                if (_11797)
                {
                    _11803 = all(bool2(_19658.x < 1.0f.xx.x, _19658.y < 1.0f.xx.y));
                }
                else
                {
                    _11803 = _11797;
                }
                _6141 = _11803;
            }
            else
            {
                _6141 = _6135;
            }
            bool _6146;
            if (_6141)
            {
                bool _11808 = all(bool2(_19660.x > 0.0f.xx.x, _19660.y > 0.0f.xx.y));
                bool _11814;
                if (_11808)
                {
                    _11814 = all(bool2(_19660.x < 1.0f.xx.x, _19660.y < 1.0f.xx.y));
                }
                else
                {
                    _11814 = _11808;
                }
                _6146 = _11814;
            }
            else
            {
                _6146 = _6141;
            }
            bool _20220;
            float4 _20229;
            if (_6146)
            {
                uint _11821_dummy_parameter;
                float _11845 = log((r_depth_tm1.Load(int3(int2(floor(_19658 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11821_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _11853_dummy_parameter;
                float _11877 = log((r_depth_tp1.Load(int3(int2(floor(_19660 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11853_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _6157 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6164;
                if (_6157)
                {
                    _6164 = _11877 > (_11845 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6164 = _6157;
                }
                bool _20225;
                float4 _20247;
                if (_6164)
                {
                    _20247 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20225 = true;
                }
                else
                {
                    bool _6170 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6177;
                    if (_6170)
                    {
                        _6177 = _11845 > (_11877 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6177 = _6170;
                    }
                    bool4 _23477 = _6177.xxxx;
                    _20247 = float4(_23477.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20234.x, _23477.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20234.y, _23477.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20234.z, _23477.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20234.w);
                    _20225 = _6177 ? true : false;
                }
                _20229 = _20247;
                _20220 = _20225;
            }
            else
            {
                _20229 = _20234;
                _20220 = false;
            }
            float4 _20302;
            if (_20220)
            {
                _20302 = 1.0f.xxxx;
            }
            else
            {
                bool _6188 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6194;
                if (_6188)
                {
                    _6194 = _20229.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6194 = _6188;
                }
                bool _6199;
                if (_6194)
                {
                    bool _11883 = all(bool2(_19660.x > 0.0f.xx.x, _19660.y > 0.0f.xx.y));
                    bool _11889;
                    if (_11883)
                    {
                        _11889 = all(bool2(_19660.x < 1.0f.xx.x, _19660.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11889 = _11883;
                    }
                    _6199 = _11889;
                }
                else
                {
                    _6199 = _6194;
                }
                float4 _20303;
                if (_6199)
                {
                    float _20256;
                    if (_20208 >= 0.0f)
                    {
                        _20256 = _20208 - _6132;
                    }
                    else
                    {
                        float _20252;
                        _20252 = 2.0f;
                        float _11946;
                        for (int _20251 = 0; _20251 < 24; _20252 = _11946, _20251++)
                        {
                            float _11910 = float(_20251 & 7) * 0.785398185253143310546875f;
                            int _11912 = _20251 >> 3;
                            int _20253;
                            if (_11912 == 0)
                            {
                                _20253 = 16;
                            }
                            else
                            {
                                _20253 = (_11912 == 1) ? 48 : 96;
                            }
                            uint _11978_dummy_parameter;
                            _11946 = min(_20252, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19660 + ((cbFI_MvDepthLaneSizeRcp * float(_20253)) * float2(cos(_11910), sin(_11910))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11978_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20256 = _20252;
                    }
                    uint _12010_dummy_parameter;
                    float4 _20304;
                    if (r_depth_tp1.Load(int3(int2(floor(_19660 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12010_dummy_parameter))))), 0)).x > ((exp((_20256 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20304 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20304 = 1.0f.xxxx;
                    }
                    _20303 = _20304;
                }
                else
                {
                    _20303 = 1.0f.xxxx;
                }
                _20302 = _20303;
            }
            bool _6227 = _20208 >= 0.0f;
            bool _6228 = (!_20220) && _6227;
            bool _6235;
            if (_6228)
            {
                _6235 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6235 = _6228;
            }
            bool _6241;
            if (_6235)
            {
                _6241 = _20229.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6241 = _6235;
            }
            bool _6246;
            if (_6241)
            {
                bool _12034 = all(bool2(_19658.x > 0.0f.xx.x, _19658.y > 0.0f.xx.y));
                bool _12040;
                if (_12034)
                {
                    _12040 = all(bool2(_19658.x < 1.0f.xx.x, _19658.y < 1.0f.xx.y));
                }
                else
                {
                    _12040 = _12034;
                }
                _6246 = _12040;
            }
            else
            {
                _6246 = _6241;
            }
            float4 _20327;
            if (_6246)
            {
                float _20296;
                if (_6227)
                {
                    _20296 = _20208 - _6132;
                }
                else
                {
                    float _20292;
                    _20292 = 2.0f;
                    float _12097;
                    for (int _20291 = 0; _20291 < 24; _20292 = _12097, _20291++)
                    {
                        float _12061 = float(_20291 & 7) * 0.785398185253143310546875f;
                        int _12063 = _20291 >> 3;
                        int _20293;
                        if (_12063 == 0)
                        {
                            _20293 = 16;
                        }
                        else
                        {
                            _20293 = (_12063 == 1) ? 48 : 96;
                        }
                        uint _12113_dummy_parameter;
                        _12097 = min(_20292, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19658 + ((cbFI_MvDepthLaneSizeRcp * float(_20293)) * float2(cos(_12061), sin(_12061))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12113_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20296 = _20292;
                }
                uint _12161_dummy_parameter;
                float4 _20328;
                if (r_depth_tm1.Load(int3(int2(floor(_19658 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12161_dummy_parameter))))), 0)).x > ((exp((_20296 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19329 = _20302;
                    _19329.x = 0.0f;
                    _20328 = _19329;
                }
                else
                {
                    _20328 = _20302;
                }
                _20327 = _20328;
            }
            else
            {
                _20327 = _20302;
            }
            float4 _20340;
            if (_6228)
            {
                float _12187 = (exp(((_20208 - _6132) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6284 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6290;
                if (_6284)
                {
                    _6290 = _20229.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6290 = _6284;
                }
                bool _6295;
                if (_6290)
                {
                    bool _12192 = all(bool2(_19662.x > 0.0f.xx.x, _19662.y > 0.0f.xx.y));
                    bool _12198;
                    if (_12192)
                    {
                        _12198 = all(bool2(_19662.x < 1.0f.xx.x, _19662.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12198 = _12192;
                    }
                    _6295 = _12198;
                }
                else
                {
                    _6295 = _6290;
                }
                bool _6303;
                if (_6295)
                {
                    uint _12205_dummy_parameter;
                    _6303 = r_depth_tp1.Load(int3(int2(floor(_19662 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12205_dummy_parameter))))), 0)).x > _12187;
                }
                else
                {
                    _6303 = _6295;
                }
                float4 _20338;
                if (_6303)
                {
                    float4 _19332 = _20327;
                    _19332.w = 0.0f;
                    _20338 = _19332;
                }
                else
                {
                    _20338 = _20327;
                }
                bool _6310 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6316;
                if (_6310)
                {
                    _6316 = _20229.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6316 = _6310;
                }
                bool _6321;
                if (_6316)
                {
                    bool _12222 = all(bool2(_19661.x > 0.0f.xx.x, _19661.y > 0.0f.xx.y));
                    bool _12228;
                    if (_12222)
                    {
                        _12228 = all(bool2(_19661.x < 1.0f.xx.x, _19661.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12228 = _12222;
                    }
                    _6321 = _12228;
                }
                else
                {
                    _6321 = _6316;
                }
                bool _6329;
                if (_6321)
                {
                    uint _12235_dummy_parameter;
                    _6329 = r_depth_tm1.Load(int3(int2(floor(_19661 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12235_dummy_parameter))))), 0)).x > _12187;
                }
                else
                {
                    _6329 = _6321;
                }
                float4 _20341;
                if (_6329)
                {
                    float4 _19335 = _20338;
                    _19335.z = 0.0f;
                    _20341 = _19335;
                }
                else
                {
                    _20341 = _20338;
                }
                _20340 = _20341;
            }
            else
            {
                _20340 = _20327;
            }
            float4 _20412;
            if (any(bool4(_20340.x < 1.0f.xxxx.x, _20340.y < 1.0f.xxxx.y, _20340.z < 1.0f.xxxx.z, _20340.w < 1.0f.xxxx.w)))
            {
                float4 _6340 = _20229 * _20340;
                float _6342 = dot(_6340, 1.0f.xxxx);
                float4 _20413;
                if (_6342 > 0.0f)
                {
                    _20413 = _6340 / _6342.xxxx;
                }
                else
                {
                    bool _6353 = _20340.y == 0.0f;
                    bool _6359;
                    if (_6353)
                    {
                        _6359 = _20340.x > 0.0f;
                    }
                    else
                    {
                        _6359 = _6353;
                    }
                    bool _6364;
                    if (_6359)
                    {
                        bool _12252 = all(bool2(_19658.x > 0.0f.xx.x, _19658.y > 0.0f.xx.y));
                        bool _12258;
                        if (_12252)
                        {
                            _12258 = all(bool2(_19658.x < 1.0f.xx.x, _19658.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12258 = _12252;
                        }
                        _6364 = _12258;
                    }
                    else
                    {
                        _6364 = _6359;
                    }
                    float4 _20414;
                    if (_6364)
                    {
                        _20414 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6369 = _20340.x == 0.0f;
                        bool _6375;
                        if (_6369)
                        {
                            _6375 = _20340.y > 0.0f;
                        }
                        else
                        {
                            _6375 = _6369;
                        }
                        bool _6380;
                        if (_6375)
                        {
                            bool _12263 = all(bool2(_19660.x > 0.0f.xx.x, _19660.y > 0.0f.xx.y));
                            bool _12269;
                            if (_12263)
                            {
                                _12269 = all(bool2(_19660.x < 1.0f.xx.x, _19660.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12269 = _12263;
                            }
                            _6380 = _12269;
                        }
                        else
                        {
                            _6380 = _6375;
                        }
                        bool4 _23480 = _6380.xxxx;
                        _20414 = float4(_23480.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20229.x, _23480.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20229.y, _23480.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20229.z, _23480.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20229.w);
                    }
                    _20413 = _20414;
                }
                _20412 = _20413;
            }
            else
            {
                _20412 = _20229;
            }
            _20411 = _20412;
        }
        else
        {
            _20411 = _20234;
        }
        float4 _21141;
        bool _21447;
        float3 _21771;
        if (((cbFI_pad0 & 32768u) != 0u) && _6089)
        {
            bool _6397 = _20411.x > 0.00999999977648258209228515625f;
            bool _6400 = _20411.y > 0.00999999977648258209228515625f;
            bool _6409 = (_20411.z + _20411.w) > 0.0199999995529651641845703125f;
            bool _6415;
            if (_6409)
            {
                bool _12274 = all(bool2(_19661.x > 0.0f.xx.x, _19661.y > 0.0f.xx.y));
                bool _12280;
                if (_12274)
                {
                    _12280 = all(bool2(_19661.x < 1.0f.xx.x, _19661.y < 1.0f.xx.y));
                }
                else
                {
                    _12280 = _12274;
                }
                _6415 = _12280;
            }
            else
            {
                _6415 = _6409;
            }
            bool _6420;
            if (_6415)
            {
                bool _12285 = all(bool2(_19662.x > 0.0f.xx.x, _19662.y > 0.0f.xx.y));
                bool _12291;
                if (_12285)
                {
                    _12291 = all(bool2(_19662.x < 1.0f.xx.x, _19662.y < 1.0f.xx.y));
                }
                else
                {
                    _12291 = _12285;
                }
                _6420 = _12291;
            }
            else
            {
                _6420 = _6415;
            }
            bool _6427;
            if (_6420)
            {
                float _20427;
                do
                {
                    bool _12374 = all(bool2(_19661.x > 0.0f.xx.x, _19661.y > 0.0f.xx.y));
                    bool _12380;
                    if (_12374)
                    {
                        _12380 = all(bool2(_19661.x < 1.0f.xx.x, _19661.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12380 = _12374;
                    }
                    bool _12311 = !_12380;
                    bool _12318;
                    if (!_12311)
                    {
                        bool _12385 = all(bool2(_19662.x > 0.0f.xx.x, _19662.y > 0.0f.xx.y));
                        bool _12391;
                        if (_12385)
                        {
                            _12391 = all(bool2(_19662.x < 1.0f.xx.x, _19662.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12391 = _12385;
                        }
                        _12318 = !_12391;
                    }
                    else
                    {
                        _12318 = _12311;
                    }
                    if (_12318)
                    {
                        _20427 = 0.0f;
                        break;
                    }
                    uint _12398_dummy_parameter;
                    uint _12414_dummy_parameter;
                    float4x4 _20426;
                    do
                    {
                        float4x4 _12428;
                        bool _20425;
                        do
                        {
                            _12428 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20425 = false;
                                break;
                            }
                            uint _12462 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12462 + 32u) * 4 + 0) != 1u)
                            {
                                _20425 = false;
                                break;
                            }
                            uint _20422;
                            _20422 = 0u;
                            for (; _20422 < 4u; _20422++)
                            {
                                for (uint _20423 = 0u; _20423 < 4u; )
                                {
                                    _12428[_20422][_20423] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12462 + 16u) + (_20422 * 4u)) + _20423) * 4 + 0));
                                    _20423++;
                                    continue;
                                }
                            }
                            _20425 = true;
                            break;
                        } while(false);
                        if (_20425)
                        {
                            _20426 = _12428;
                            break;
                        }
                        _20426 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12339 = mul(float4((float2(_19661.x, 1.0f - _19661.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19661 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12398_dummy_parameter))))), 0)).x, 1.0f), _20426);
                    float _12341 = _12339.w;
                    if (abs(_12341) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20427 = 0.0f;
                        break;
                    }
                    float _12352 = abs(cbFI_DeviceToViewDepth.y / ((_12339.z / _12341) - cbFI_DeviceToViewDepth.x));
                    float _12355 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19662 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12414_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20427 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12352 - _12355) / max(max(_12352, _12355), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6427 = _20427 < 0.5f;
            }
            else
            {
                _6427 = _6420;
            }
            float4 _20446;
            if (_6427)
            {
                uint _12566_dummy_parameter;
                uint _12597_dummy_parameter;
                float4 _20447;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19661 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12566_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19662 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12597_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20447 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20447 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20446 = _20447;
            }
            else
            {
                _20446 = 1.0f.xxxx;
            }
            bool _6451;
            if (_11035)
            {
                bool _12626 = all(bool2(_19658.x > 0.0f.xx.x, _19658.y > 0.0f.xx.y));
                bool _12632;
                if (_12626)
                {
                    _12632 = all(bool2(_19658.x < 1.0f.xx.x, _19658.y < 1.0f.xx.y));
                }
                else
                {
                    _12632 = _12626;
                }
                _6451 = _12632;
            }
            else
            {
                _6451 = _11035;
            }
            bool _6457;
            if (_11035)
            {
                bool _12637 = all(bool2(_19660.x > 0.0f.xx.x, _19660.y > 0.0f.xx.y));
                bool _12643;
                if (_12637)
                {
                    _12643 = all(bool2(_19660.x < 1.0f.xx.x, _19660.y < 1.0f.xx.y));
                }
                else
                {
                    _12643 = _12637;
                }
                _6457 = _12643;
            }
            else
            {
                _6457 = _11035;
            }
            bool _6463;
            if (_11067)
            {
                bool _12648 = all(bool2(_19661.x > 0.0f.xx.x, _19661.y > 0.0f.xx.y));
                bool _12654;
                if (_12648)
                {
                    _12654 = all(bool2(_19661.x < 1.0f.xx.x, _19661.y < 1.0f.xx.y));
                }
                else
                {
                    _12654 = _12648;
                }
                _6463 = _12654;
            }
            else
            {
                _6463 = _11067;
            }
            bool _6469;
            if (_11067)
            {
                bool _12659 = all(bool2(_19662.x > 0.0f.xx.x, _19662.y > 0.0f.xx.y));
                bool _12665;
                if (_12659)
                {
                    _12665 = all(bool2(_19662.x < 1.0f.xx.x, _19662.y < 1.0f.xx.y));
                }
                else
                {
                    _12665 = _12659;
                }
                _6469 = _12665;
            }
            else
            {
                _6469 = _11067;
            }
            bool _6472 = _6463 != _6469;
            bool _6478;
            if (_6472)
            {
                _6478 = _6451 || _6457;
            }
            else
            {
                _6478 = _6472;
            }
            float4 _20549;
            if (_6478)
            {
                float4 _19362 = _20446;
                _19362.z = 0.0f;
                _19362.w = 0.0f;
                _20549 = _19362;
            }
            else
            {
                _20549 = _20446;
            }
            bool _6485 = _6451 && _6397;
            bool _6488 = _6457 && _6400;
            float4 _20654;
            float3 _21880;
            if (_6485 || _6488)
            {
                float _20544;
                do
                {
                    uint4 _12804 = r_warped_motion_qdata_tp1.Load(int3(_19879, 0));
                    uint _12805 = _12804.x;
                    if (_12805 != 0u)
                    {
                        float _20543;
                        if (_12805 == 0u)
                        {
                            _20543 = -1.0f;
                        }
                        else
                        {
                            _20543 = float((_12805 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20544 = _20543;
                        break;
                    }
                    int _20526;
                    uint _20527;
                    _20527 = _12805;
                    _20526 = -1;
                    uint _20542;
                    for (; _20526 <= 1; _20527 = _20542, _20526++)
                    {
                        _20542 = _20527;
                        for (int _20540 = -1; _20540 <= 1; )
                        {
                            _20542 = max(_20542, r_warped_motion_qdata_tp1.Load(int3(clamp(_19879 + int2(_20540, _20526), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20540++;
                            continue;
                        }
                    }
                    if (_20527 != 0u)
                    {
                        float _20539;
                        if (_20527 == 0u)
                        {
                            _20539 = -1.0f;
                        }
                        else
                        {
                            _20539 = float((_20527 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20544 = _20539;
                        break;
                    }
                    uint _20529;
                    _20529 = 4294967295u;
                    uint _23369;
                    for (int _20528 = 0; _20528 < 8; _20529 = _23369, _20528++)
                    {
                        int _20532 = 0;
                        for (;;)
                        {
                            if (_20532 < 5)
                            {
                                int2 _12755 = _19879 + (_1243[_20528] * _1252[_20532].xx);
                                bool _12758 = any(bool2(_12755.x < int2(0, 0).x, _12755.y < int2(0, 0).y));
                                bool _12766;
                                if (!_12758)
                                {
                                    _12766 = any(bool2(_12755.x >= cbFI_MvDepthLaneSize.x, _12755.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12766 = _12758;
                                }
                                if (_12766)
                                {
                                    _23369 = _20529;
                                    break;
                                }
                                uint4 _12844 = r_warped_motion_qdata_tp1.Load(int3(_12755, 0));
                                uint _12845 = _12844.x;
                                if (_12845 != 0u)
                                {
                                    _23369 = min(_20529, _12845);
                                    break;
                                }
                                _20532++;
                                continue;
                            }
                            else
                            {
                                _23369 = _20529;
                                break;
                            }
                        }
                    }
                    float _20531;
                    if (_20529 == 4294967295u)
                    {
                        _20531 = -1.0f;
                    }
                    else
                    {
                        float _20530;
                        if (_20529 == 0u)
                        {
                            _20530 = -1.0f;
                        }
                        else
                        {
                            _20530 = float((_20529 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20531 = _20530;
                    }
                    _20544 = _20531;
                    break;
                } while(false);
                bool _6496 = _20544 < 0.0f;
                float _20545;
                if (_6496)
                {
                    _20545 = 0.0f;
                }
                else
                {
                    _20545 = _20544 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12866_dummy_parameter;
                uint _12898_dummy_parameter;
                float4 _20582;
                if ((_6496 && _6485) && _6488)
                {
                    uint _12930_dummy_parameter;
                    float _12954 = log((r_depth_tm1.Load(int3(int2(floor(_19658 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12930_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12962_dummy_parameter;
                    float _12986 = log((r_depth_tp1.Load(int3(int2(floor(_19660 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12962_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20583;
                    if (_12954 > (_12986 + 0.07999999821186065673828125f))
                    {
                        float4 _19366 = _20549;
                        _19366.x = 0.0f;
                        _20583 = _19366;
                    }
                    else
                    {
                        float4 _20584;
                        if (_12986 > (_12954 + 0.07999999821186065673828125f))
                        {
                            float4 _19368 = _20549;
                            _19368.y = 0.0f;
                            _20584 = _19368;
                        }
                        else
                        {
                            _20584 = _20549;
                        }
                        _20583 = _20584;
                    }
                    _20582 = _20583;
                }
                else
                {
                    _20582 = _20549;
                }
                float _6548 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6550 = _20544 >= 0.0f;
                float _20565;
                if (_6550)
                {
                    _20565 = _20544 - _6548;
                }
                else
                {
                    float _20561;
                    if (_6485)
                    {
                        float _20560;
                        _20560 = 2.0f;
                        float _13044;
                        for (int _20559 = 0; _20559 < 24; _20560 = _13044, _20559++)
                        {
                            float _13008 = float(_20559 & 7) * 0.785398185253143310546875f;
                            int _13010 = _20559 >> 3;
                            int _20562;
                            if (_13010 == 0)
                            {
                                _20562 = 16;
                            }
                            else
                            {
                                _20562 = (_13010 == 1) ? 48 : 96;
                            }
                            uint _13060_dummy_parameter;
                            _13044 = min(_20560, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19658 + ((cbFI_MvDepthLaneSizeRcp * float(_20562)) * float2(cos(_13008), sin(_13008))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13060_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20561 = _20560;
                    }
                    else
                    {
                        _20561 = 0.0f;
                    }
                    _20565 = _20561;
                }
                float _20572;
                if (_6550)
                {
                    _20572 = _20544 - _6548;
                }
                else
                {
                    float _20568;
                    if (_6488)
                    {
                        float _20567;
                        _20567 = 2.0f;
                        float _13158;
                        for (int _20566 = 0; _20566 < 24; _20567 = _13158, _20566++)
                        {
                            float _13122 = float(_20566 & 7) * 0.785398185253143310546875f;
                            int _13124 = _20566 >> 3;
                            int _20569;
                            if (_13124 == 0)
                            {
                                _20569 = 16;
                            }
                            else
                            {
                                _20569 = (_13124 == 1) ? 48 : 96;
                            }
                            uint _13190_dummy_parameter;
                            _13158 = min(_20567, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19660 + ((cbFI_MvDepthLaneSizeRcp * float(_20569)) * float2(cos(_13122), sin(_13122))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13190_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20568 = _20567;
                    }
                    else
                    {
                        _20568 = 0.0f;
                    }
                    _20572 = _20568;
                }
                float _20573;
                if (_6485)
                {
                    uint _13222_dummy_parameter;
                    _20573 = r_depth_tm1.Load(int3(int2(floor(_19658 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13222_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20573 = 0.0f;
                }
                float _20574;
                if (_6488)
                {
                    uint _13241_dummy_parameter;
                    _20574 = r_depth_tp1.Load(int3(int2(floor(_19660 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13241_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20574 = 0.0f;
                }
                bool _6605;
                if (_6485)
                {
                    _6605 = _20573 > ((exp((_20565 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6605 = _6485;
                }
                float4 _20590;
                if (_6605)
                {
                    float4 _19370 = _20582;
                    _19370.x = 0.0f;
                    _20590 = _19370;
                }
                else
                {
                    _20590 = _20582;
                }
                bool _6617;
                if (_6488)
                {
                    _6617 = _20574 > ((exp((_20572 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6617 = _6488;
                }
                float4 _20592;
                if (_6617)
                {
                    float4 _19372 = _20590;
                    _19372.y = 0.0f;
                    _20592 = _19372;
                }
                else
                {
                    _20592 = _20590;
                }
                float4 _20655;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6550)
                {
                    bool _6637;
                    if (_6485)
                    {
                        _6637 = _20573 < ((exp((_20565 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6637 = _6485;
                    }
                    float4 _20594;
                    if (_6637)
                    {
                        float4 _19374 = _20592;
                        _19374.x = 0.0f;
                        _20594 = _19374;
                    }
                    else
                    {
                        _20594 = _20592;
                    }
                    bool _6649;
                    if (_6488)
                    {
                        _6649 = _20574 < ((exp((_20572 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6649 = _6488;
                    }
                    float4 _20656;
                    if (_6649)
                    {
                        float4 _19376 = _20594;
                        _19376.y = 0.0f;
                        _20656 = _19376;
                    }
                    else
                    {
                        _20656 = _20594;
                    }
                    _20655 = _20656;
                }
                else
                {
                    _20655 = _20592;
                }
                _21880 = float3(_20545, log((r_depth_tm1.Load(int3(int2(floor(_19658 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12866_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_19660 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12898_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _20654 = _20655;
            }
            else
            {
                _21880 = float3(0.0f, 0.0f, 0.5f);
                _20654 = _20549;
            }
            bool _6660 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6409;
            bool _6666;
            if (_6660)
            {
                _6666 = _6463 || _6469;
            }
            else
            {
                _6666 = _6660;
            }
            float4 _20697;
            if (_6666)
            {
                float _20649;
                do
                {
                    uint4 _13420 = r_warped_motion_qdata_tp1.Load(int3(_19879, 0));
                    uint _13421 = _13420.x;
                    if (_13421 != 0u)
                    {
                        float _20648;
                        if (_13421 == 0u)
                        {
                            _20648 = -1.0f;
                        }
                        else
                        {
                            _20648 = float((_13421 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20649 = _20648;
                        break;
                    }
                    int _20631;
                    uint _20632;
                    _20632 = _13421;
                    _20631 = -1;
                    uint _20647;
                    for (; _20631 <= 1; _20632 = _20647, _20631++)
                    {
                        _20647 = _20632;
                        for (int _20645 = -1; _20645 <= 1; )
                        {
                            _20647 = max(_20647, r_warped_motion_qdata_tp1.Load(int3(clamp(_19879 + int2(_20645, _20631), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20645++;
                            continue;
                        }
                    }
                    if (_20632 != 0u)
                    {
                        float _20644;
                        if (_20632 == 0u)
                        {
                            _20644 = -1.0f;
                        }
                        else
                        {
                            _20644 = float((_20632 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20649 = _20644;
                        break;
                    }
                    uint _20634;
                    _20634 = 4294967295u;
                    uint _23370;
                    for (int _20633 = 0; _20633 < 8; _20634 = _23370, _20633++)
                    {
                        int _20637 = 0;
                        for (;;)
                        {
                            if (_20637 < 5)
                            {
                                int2 _13371 = _19879 + (_1243[_20633] * _1252[_20637].xx);
                                bool _13374 = any(bool2(_13371.x < int2(0, 0).x, _13371.y < int2(0, 0).y));
                                bool _13382;
                                if (!_13374)
                                {
                                    _13382 = any(bool2(_13371.x >= cbFI_MvDepthLaneSize.x, _13371.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13382 = _13374;
                                }
                                if (_13382)
                                {
                                    _23370 = _20634;
                                    break;
                                }
                                uint4 _13460 = r_warped_motion_qdata_tp1.Load(int3(_13371, 0));
                                uint _13461 = _13460.x;
                                if (_13461 != 0u)
                                {
                                    _23370 = min(_20634, _13461);
                                    break;
                                }
                                _20637++;
                                continue;
                            }
                            else
                            {
                                _23370 = _20634;
                                break;
                            }
                        }
                    }
                    float _20636;
                    if (_20634 == 4294967295u)
                    {
                        _20636 = -1.0f;
                    }
                    else
                    {
                        float _20635;
                        if (_20634 == 0u)
                        {
                            _20635 = -1.0f;
                        }
                        else
                        {
                            _20635 = float((_20634 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20636 = _20635;
                    }
                    _20649 = _20636;
                    break;
                } while(false);
                float4 _20698;
                if (_20649 >= 0.0f)
                {
                    float _13482 = (exp((_20649 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6685;
                    if (_6463)
                    {
                        uint _13489_dummy_parameter;
                        _6685 = r_depth_tm1.Load(int3(int2(floor(_19661 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13489_dummy_parameter))))), 0)).x > _13482;
                    }
                    else
                    {
                        _6685 = _6463;
                    }
                    float4 _20667;
                    if (_6685)
                    {
                        float4 _19378 = _20654;
                        _19378.z = 0.0f;
                        _20667 = _19378;
                    }
                    else
                    {
                        _20667 = _20654;
                    }
                    bool _6697;
                    if (_6469)
                    {
                        uint _13508_dummy_parameter;
                        _6697 = r_depth_tp1.Load(int3(int2(floor(_19662 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13508_dummy_parameter))))), 0)).x > _13482;
                    }
                    else
                    {
                        _6697 = _6469;
                    }
                    float4 _20699;
                    if (_6697)
                    {
                        float4 _19380 = _20667;
                        _19380.w = 0.0f;
                        _20699 = _19380;
                    }
                    else
                    {
                        _20699 = _20667;
                    }
                    _20698 = _20699;
                }
                else
                {
                    _20698 = _20654;
                }
                _20697 = _20698;
            }
            else
            {
                _20697 = _20654;
            }
            bool _6705 = _6451 != _6457;
            bool _6712;
            if (_6705)
            {
                _6712 = _6451 ? _6397 : _6400;
            }
            else
            {
                _6712 = _6705;
            }
            bool _6719;
            if (_6712)
            {
                _6719 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6719 = _6712;
            }
            float4 _20800;
            if (_6719)
            {
                bool2 _6724 = _6451.xx;
                float2 _6725 = float2(_6724.x ? _19658.x : _19660.x, _6724.y ? _19658.y : _19660.y);
                float _20681;
                if (_6451)
                {
                    uint _13527_dummy_parameter;
                    _20681 = r_depth_tm1.Load(int3(int2(floor(_6725 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13527_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13543_dummy_parameter;
                    _20681 = r_depth_tp1.Load(int3(int2(floor(_6725 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13543_dummy_parameter))))), 0)).x;
                }
                float4x4 _20688;
                if (_6451)
                {
                    float4x4 _20677;
                    do
                    {
                        float4x4 _13557;
                        bool _20676;
                        do
                        {
                            _13557 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20676 = false;
                                break;
                            }
                            uint _13591 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13591 + 32u) * 4 + 0) != 1u)
                            {
                                _20676 = false;
                                break;
                            }
                            uint _20673;
                            _20673 = 0u;
                            for (; _20673 < 4u; _20673++)
                            {
                                for (uint _20674 = 0u; _20674 < 4u; )
                                {
                                    _13557[_20673][_20674] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13591 + 16u) + (_20673 * 4u)) + _20674) * 4 + 0));
                                    _20674++;
                                    continue;
                                }
                            }
                            _20676 = true;
                            break;
                        } while(false);
                        if (_20676)
                        {
                            _20677 = _13557;
                            break;
                        }
                        _20677 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20688 = _20677;
                }
                else
                {
                    float4x4 _20672;
                    do
                    {
                        float4x4 _13663;
                        bool _20671;
                        do
                        {
                            _13663 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20671 = false;
                                break;
                            }
                            uint _13697 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13697 + 32u) * 4 + 0) != 1u)
                            {
                                _20671 = false;
                                break;
                            }
                            uint _20668;
                            _20668 = 0u;
                            for (; _20668 < 4u; _20668++)
                            {
                                for (uint _20669 = 0u; _20669 < 4u; )
                                {
                                    _13663[_20668][_20669] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13697 + (_20668 * 4u)) + _20669) * 4 + 0));
                                    _20669++;
                                    continue;
                                }
                            }
                            _20671 = true;
                            break;
                        } while(false);
                        if (_20671)
                        {
                            _20672 = _13663;
                            break;
                        }
                        _20672 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20688 = _20672;
                }
                float2 _20689;
                do
                {
                    float _13774 = _6725.x;
                    float _13777 = 1.0f - _6725.y;
                    float4 _13788 = mul(float4((float2(_13774, _13777) * 2.0f) - 1.0f.xx, _20681, 1.0f), _20688);
                    float _13790 = _13788.w;
                    if (!(_13790 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20689 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13803 = ((_13788.xy / _13790.xx) + 1.0f.xx) * 0.5f;
                    _20689 = float2(_13803.x - _13774, _13777 - _13803.y);
                    break;
                } while(false);
                float2 _6755 = float2(cbFI_DisplaySize);
                float4 _20801;
                if (!(length(((_6725 + _20689) - float2(_6724.x ? _19660.x : _19658.x, _6724.y ? _19660.y : _19658.y)) * _6755) <= ((0.100000001490116119384765625f * length(_20689 * _6755)) + 8.0f)))
                {
                    float4 _20802;
                    if (_6451)
                    {
                        float4 _19390 = _20697;
                        _19390.x = 0.0f;
                        _20802 = _19390;
                    }
                    else
                    {
                        float4 _19392 = _20697;
                        _19392.y = 0.0f;
                        _20802 = _19392;
                    }
                    _20801 = _20802;
                }
                else
                {
                    _20801 = _20697;
                }
                _20800 = _20801;
            }
            else
            {
                _20800 = _20697;
            }
            float4 _6780 = _20411 * _20800;
            float _6782 = dot(_6780, 1.0f.xxxx);
            float4 _21142;
            bool _21448;
            if (_6782 > 0.0f)
            {
                _21448 = _20102;
                _21142 = _6780 / _6782.xxxx;
            }
            else
            {
                bool _6793 = any(bool4(_20800.x < 1.0f.xxxx.x, _20800.y < 1.0f.xxxx.y, _20800.z < 1.0f.xxxx.z, _20800.w < 1.0f.xxxx.w));
                if (_6793)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13825;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13825);
                    }
                }
                bool4 _23483 = _6793.xxxx;
                _21448 = _6793 ? true : _20102;
                _21142 = float4(_23483.x ? 0.0f.xxxx.x : _20411.x, _23483.y ? 0.0f.xxxx.y : _20411.y, _23483.z ? 0.0f.xxxx.z : _20411.z, _23483.w ? 0.0f.xxxx.w : _20411.w);
            }
            _21771 = _21880;
            _21447 = _21448;
            _21141 = _21142;
        }
        else
        {
            _21771 = float3(0.0f, 0.0f, 0.5f);
            _21447 = _20102;
            _21141 = _20411;
        }
        uint _6802 = (cbFI_pad0 >> 24u) & 31u;
        uint _6806 = (cbFI_pad0 >> 16u) & 255u;
        bool _6808 = _6802 != 0u;
        bool _6810 = _6806 == 12u;
        bool _6813 = _6806 == 13u;
        float4 _21162;
        if ((_6808 || _6810) || _6813)
        {
            float _20808;
            do
            {
                bool _13909 = all(bool2(_19661.x > 0.0f.xx.x, _19661.y > 0.0f.xx.y));
                bool _13915;
                if (_13909)
                {
                    _13915 = all(bool2(_19661.x < 1.0f.xx.x, _19661.y < 1.0f.xx.y));
                }
                else
                {
                    _13915 = _13909;
                }
                bool _13846 = !_13915;
                bool _13853;
                if (!_13846)
                {
                    bool _13920 = all(bool2(_19662.x > 0.0f.xx.x, _19662.y > 0.0f.xx.y));
                    bool _13926;
                    if (_13920)
                    {
                        _13926 = all(bool2(_19662.x < 1.0f.xx.x, _19662.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13926 = _13920;
                    }
                    _13853 = !_13926;
                }
                else
                {
                    _13853 = _13846;
                }
                if (_13853)
                {
                    _20808 = 0.0f;
                    break;
                }
                uint _13933_dummy_parameter;
                uint _13949_dummy_parameter;
                float4x4 _20807;
                do
                {
                    float4x4 _13963;
                    bool _20806;
                    do
                    {
                        _13963 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20806 = false;
                            break;
                        }
                        uint _13997 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_13997 + 32u) * 4 + 0) != 1u)
                        {
                            _20806 = false;
                            break;
                        }
                        uint _20803;
                        _20803 = 0u;
                        for (; _20803 < 4u; _20803++)
                        {
                            for (uint _20804 = 0u; _20804 < 4u; )
                            {
                                _13963[_20803][_20804] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13997 + 16u) + (_20803 * 4u)) + _20804) * 4 + 0));
                                _20804++;
                                continue;
                            }
                        }
                        _20806 = true;
                        break;
                    } while(false);
                    if (_20806)
                    {
                        _20807 = _13963;
                        break;
                    }
                    _20807 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13874 = mul(float4((float2(_19661.x, 1.0f - _19661.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19661 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13933_dummy_parameter))))), 0)).x, 1.0f), _20807);
                float _13876 = _13874.w;
                if (abs(_13876) < 9.9999999747524270787835121154785e-07f)
                {
                    _20808 = 0.0f;
                    break;
                }
                float _13887 = abs(cbFI_DeviceToViewDepth.y / ((_13874.z / _13876) - cbFI_DeviceToViewDepth.x));
                float _13890 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19662 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13949_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20808 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13887 - _13890) / max(max(_13887, _13890), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14099 = all(bool2(_19662.x > 0.0f.xx.x, _19662.y > 0.0f.xx.y));
            bool _14105;
            if (_14099)
            {
                _14105 = all(bool2(_19662.x < 1.0f.xx.x, _19662.y < 1.0f.xx.y));
            }
            else
            {
                _14105 = _14099;
            }
            float _20809;
            if (_14105)
            {
                uint _14112_dummy_parameter;
                _20809 = length((_7933 + (r_motion_tp1.Load(int3(int2(floor(_19662 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14112_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20809 = 1000000.0f;
            }
            float _20824;
            if ((_6802 & 1u) != 0u)
            {
                _20824 = _20808;
            }
            else
            {
                _20824 = 1.0f;
            }
            float _20825;
            if ((_6802 & 2u) != 0u)
            {
                _20825 = _20824 * (1.0f - smoothstep(2.0f, 8.0f, _20809));
            }
            else
            {
                _20825 = _20824;
            }
            float _20826;
            if ((_6802 & 4u) != 0u)
            {
                _20826 = _20825 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8654 - _8662) - length(_8638 - _8646))));
            }
            else
            {
                _20826 = _20825;
            }
            float _21156;
            if ((_6802 & 8u) != 0u)
            {
                _21156 = lerp(1.0f, _20826, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8638 - _8646)));
            }
            else
            {
                _21156 = _20826;
            }
            bool _6888 = (_6802 & 16u) != 0u;
            bool _6897;
            if (_6888)
            {
                _6897 = length(_19656 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6897 = _6888;
            }
            float _23485 = _6897 ? 1.0f : _21156;
            bool _6903 = _6808 && _11035;
            bool _6908;
            if (_6903)
            {
                bool _14137 = all(bool2(_19658.x > 0.0f.xx.x, _19658.y > 0.0f.xx.y));
                bool _14143;
                if (_14137)
                {
                    _14143 = all(bool2(_19658.x < 1.0f.xx.x, _19658.y < 1.0f.xx.y));
                }
                else
                {
                    _14143 = _14137;
                }
                _6908 = _14143;
            }
            else
            {
                _6908 = _6903;
            }
            bool _6913;
            if (_6908)
            {
                bool _14148 = all(bool2(_19660.x > 0.0f.xx.x, _19660.y > 0.0f.xx.y));
                bool _14154;
                if (_14148)
                {
                    _14154 = all(bool2(_19660.x < 1.0f.xx.x, _19660.y < 1.0f.xx.y));
                }
                else
                {
                    _14154 = _14148;
                }
                _6913 = _14154;
            }
            else
            {
                _6913 = _6908;
            }
            float4 _21163;
            if (_6913)
            {
                float _6919 = _21141.x + _21141.y;
                float _6928 = (_21141.z + _21141.w) * (1.0f - _23485);
                float _21159;
                if (_6919 > 9.9999997473787516355514526367188e-06f)
                {
                    _21159 = _21141.x / _6919;
                }
                else
                {
                    _21159 = _5658;
                }
                _21163 = float4(_21141.x + (_6928 * _21159), _21141.y + (_6928 * (1.0f - _21159)), _21141.zw * _23485);
            }
            else
            {
                _21163 = _21141;
            }
            _21162 = _21163;
        }
        else
        {
            _21162 = _21141;
        }
        float3 _6989 = (((_8638 * _21162.x) + (_8646 * _21162.y)) + (_8654 * _21162.z)) + (_8662 * _21162.w);
        float3 _23118;
        if (_5674 && (_21177 > 0.0f))
        {
            uint _14161_dummy_parameter;
            float2 _14176 = r_motion_tp1.Load(int3(int2(floor(_5433 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14161_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21439;
            if (_7961)
            {
                float2 _14221 = clamp((((_19635 + (_14176 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14224 = tan(_14221.x);
                _21439 = (float2(_14224 / cbFI_DeviceToViewDepth.z, (tan(_14221.y) * sqrt(1.0f + (_14224 * _14224))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21439 = _19635 + (_14176 * cbFI_Timestep);
            }
            float2 _21440;
            if (_7961)
            {
                float2 _14300 = clamp((((_19635 + (_14176 * _5648)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14303 = tan(_14300.x);
                _21440 = (float2(_14303 / cbFI_DeviceToViewDepth.z, (tan(_14300.y) * sqrt(1.0f + (_14303 * _14303))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21440 = _19635 + (_14176 * _5648);
            }
            _23118 = lerp(_6989, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21439, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21440, 0.0f).xyz, cbFI_Timestep.xxx), _21177.xxx);
        }
        else
        {
            _23118 = _6989;
        }
        float3 _23117;
        if (_21447)
        {
            float3 _14345 = r_current_interpolation_source.Load(int3(_4934, 0)).xyz;
            float3 _23119;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11035)
            {
                uint _14352_dummy_parameter;
                float _21570;
                _21570 = r_depth_tm1.Load(int3(int2(floor(_19658 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14352_dummy_parameter))))), 0)).x;
                float _7070;
                for (int _21569 = 0; _21569 < 24; _21570 = _7070, _21569++)
                {
                    float _7042 = float(_21569 & 7) * 0.785398185253143310546875f;
                    int _7044 = _21569 >> 3;
                    int _23212;
                    if (_7044 == 0)
                    {
                        _23212 = 16;
                    }
                    else
                    {
                        _23212 = (_7044 == 1) ? 48 : 96;
                    }
                    uint _14372_dummy_parameter;
                    _7070 = min(_21570, r_depth_tm1.Load(int3(int2(floor(clamp(_19658 + ((cbFI_MvDepthLaneSizeRcp * float(_23212)) * float2(cos(_7042), sin(_7042))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14372_dummy_parameter))))), 0)).x);
                }
                float2 _21571;
                do
                {
                    float _14394 = 1.0f - _19658.y;
                    float4 _14405 = mul(float4((float2(_19658.x, _14394) * 2.0f) - 1.0f.xx, _21570, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14407 = _14405.w;
                    if (!(_14407 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21571 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14420 = ((_14405.xy / _14407.xx) + 1.0f.xx) * 0.5f;
                    _21571 = float2(_14420.x - _19658.x, _14394 - _14420.y);
                    break;
                } while(false);
                float2 _7081 = _19658 + _21571;
                bool _14438 = all(bool2(_7081.x > 0.0f.xx.x, _7081.y > 0.0f.xx.y));
                bool _14444;
                if (_14438)
                {
                    _14444 = all(bool2(_7081.x < 1.0f.xx.x, _7081.y < 1.0f.xx.y));
                }
                else
                {
                    _14444 = _14438;
                }
                float3 _23120;
                if (_14444)
                {
                    float _7087 = abs(cbFI_DeviceToViewDepth.y / (_21570 - cbFI_DeviceToViewDepth.x));
                    uint _14464_dummy_parameter;
                    int2 _14464 = int2(spvTextureSize(r_depth_m2, uint(0), _14464_dummy_parameter));
                    float _7091 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7081 * float2(_14464))), int2(0, 0), _14464 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _23125;
                    if (abs(_7091 - _7087) <= (0.20000000298023223876953125f * max(_7091, _7087)))
                    {
                        uint _14498_dummy_parameter;
                        int2 _14498 = int2(spvTextureSize(r_colour_m2, uint(0), _14498_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14521;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14521);
                        }
                        _23125 = r_colour_m2.Load(int3(clamp(int2(floor(_7081 * float2(_14498))), int2(0, 0), _14498 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14531;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14531);
                        }
                        _23125 = _14345;
                    }
                    _23120 = _23125;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14541;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14541);
                    }
                    _23120 = _14345;
                }
                _23119 = _23120;
            }
            else
            {
                _23119 = _14345;
            }
            _23117 = _23119;
        }
        else
        {
            _23117 = _23118;
        }
        bool _7116 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _23116;
        float _23192;
        if (_7116)
        {
            float2 _7120 = float2(cbFI_DisplaySize);
            float3 _21753;
            float _21754;
            do
            {
                bool _14853;
                float4x4 _21578;
                do
                {
                    float4x4 _14829;
                    bool _21577;
                    do
                    {
                        _14829 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14853 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14853)
                        {
                            _21577 = false;
                            break;
                        }
                        uint _14863 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14863 + 32u) * 4 + 0) != 1u)
                        {
                            _21577 = false;
                            break;
                        }
                        uint _21574;
                        _21574 = 0u;
                        for (; _21574 < 4u; _21574++)
                        {
                            for (uint _21575 = 0u; _21575 < 4u; )
                            {
                                _14829[_21574][_21575] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14863 + (_21574 * 4u)) + _21575) * 4 + 0));
                                _21575++;
                                continue;
                            }
                        }
                        _21577 = true;
                        break;
                    } while(false);
                    if (_21577)
                    {
                        _21578 = _14829;
                        break;
                    }
                    _21578 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float4x4 _14611 = spvInverse(_21578);
                bool _14613 = _6806 == 33u;
                if (_14613 || (_6806 == 34u))
                {
                    uint _14943_dummy_parameter;
                    float2 _14958 = r_motion_tp1.Load(int3(int2(floor(clamp(_5433, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14943_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
                    float2 _21745;
                    if (_14613)
                    {
                        uint _14970_dummy_parameter;
                        float2 _21744;
                        do
                        {
                            float _14989 = _5433.x;
                            float _14992 = 1.0f - _5433.y;
                            float4 _15003 = mul(float4((float2(_14989, _14992) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5433 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _14970_dummy_parameter))))), 0)).x, 1.0f), _21578);
                            float _15005 = _15003.w;
                            if (!(_15005 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21744 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15018 = ((_15003.xy / _15005.xx) + 1.0f.xx) * 0.5f;
                            _21744 = float2(_15018.x - _14989, _14992 - _15018.y);
                            break;
                        } while(false);
                        _21745 = _21744 - _14958;
                    }
                    else
                    {
                        float2 _14633 = _5433 + _14958;
                        bool _15036 = all(bool2(_14633.x > 0.0f.xx.x, _14633.y > 0.0f.xx.y));
                        bool _15042;
                        if (_15036)
                        {
                            _15042 = all(bool2(_14633.x < 1.0f.xx.x, _14633.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15042 = _15036;
                        }
                        float2 _21743;
                        if (_15042)
                        {
                            uint _15049_dummy_parameter;
                            float2 _21742;
                            do
                            {
                                float _15068 = _14633.x;
                                float _15071 = 1.0f - _14633.y;
                                float4 _15082 = mul(float4((float2(_15068, _15071) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14633 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _15049_dummy_parameter))))), 0)).x, 1.0f), _14611);
                                float _15084 = _15082.w;
                                if (!(_15084 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21742 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _15097 = ((_15082.xy / _15084.xx) + 1.0f.xx) * 0.5f;
                                _21742 = float2(_15097.x - _15068, _15071 - _15097.y);
                                break;
                            } while(false);
                            _21743 = _21742 + _14958;
                        }
                        else
                        {
                            _21743 = 0.0f.xx;
                        }
                        _21745 = _21743;
                    }
                    bool _21752;
                    do
                    {
                        bool _15176 = all(bool2(_5433.x > 0.0f.xx.x, _5433.y > 0.0f.xx.y));
                        bool _15182;
                        if (_15176)
                        {
                            _15182 = all(bool2(_5433.x < 1.0f.xx.x, _5433.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15182 = _15176;
                        }
                        if (!_15182)
                        {
                            _21752 = false;
                            break;
                        }
                        uint _15189_dummy_parameter;
                        float4x4 _21750;
                        do
                        {
                            float4x4 _15203;
                            bool _21749;
                            do
                            {
                                _15203 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14853)
                                {
                                    _21749 = false;
                                    break;
                                }
                                uint _15237 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_15237 + 32u) * 4 + 0) != 1u)
                                {
                                    _21749 = false;
                                    break;
                                }
                                uint _21746;
                                _21746 = 0u;
                                for (; _21746 < 4u; _21746++)
                                {
                                    for (uint _21747 = 0u; _21747 < 4u; )
                                    {
                                        _15203[_21746][_21747] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15237 + (_21746 * 4u)) + _21747) * 4 + 0));
                                        _21747++;
                                        continue;
                                    }
                                }
                                _21749 = true;
                                break;
                            } while(false);
                            if (_21749)
                            {
                                _21750 = _15203;
                                break;
                            }
                            _21750 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21751;
                        do
                        {
                            float _15314 = _5433.x;
                            float _15317 = 1.0f - _5433.y;
                            float4 _15328 = mul(float4((float2(_15314, _15317) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5433 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15189_dummy_parameter))))), 0)).x, 1.0f), _21750);
                            float _15330 = _15328.w;
                            if (!(_15330 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21751 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15343 = ((_15328.xy / _15330.xx) + 1.0f.xx) * 0.5f;
                            _21751 = float2(_15343.x - _15314, _15317 - _15343.y);
                            break;
                        } while(false);
                        float2 _15140 = abs(_21751);
                        if (any(bool2(_15140.x > 100000.0f.xx.x, _15140.y > 100000.0f.xx.y)))
                        {
                            _21752 = false;
                            break;
                        }
                        float _15148 = length(_21751 * _7120);
                        uint _15363_dummy_parameter;
                        bool _15162 = _15148 > ((8.0f * _7120.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _15169;
                        if (_15162)
                        {
                            _15169 = length((r_motion_tp1.Load(int3(int2(floor(_5433 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15363_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7120) < (0.20000000298023223876953125f * _15148);
                        }
                        else
                        {
                            _15169 = _15162;
                        }
                        _21752 = _15169;
                        break;
                    } while(false);
                    _21754 = 2.0f;
                    _21753 = float3(clamp(length(_21745 * float2(cbFI_RenderSize)) * 0.25f, 0.0f, 1.0f), float(_21752), 0.0f);
                    break;
                }
                float _15397;
                float _15400;
                float4 _15410;
                float2 _21579;
                do
                {
                    _15397 = _5433.x;
                    _15400 = 1.0f - _5433.y;
                    _15410 = float4((float2(_15397, _15400) * 2.0f) - 1.0f.xx, 1.0000000116860974230803549289703e-07f, 1.0f);
                    float4 _15411 = mul(_15410, _21578);
                    float _15413 = _15411.w;
                    if (!(_15413 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21579 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15426 = ((_15411.xy / _15413.xx) + 1.0f.xx) * 0.5f;
                    _21579 = float2(_15426.x - _15397, _15400 - _15426.y);
                    break;
                } while(false);
                float2 _21580;
                do
                {
                    float4 _15463 = mul(_15410, _14611);
                    float _15465 = _15463.w;
                    if (!(_15465 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21580 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15478 = ((_15463.xy / _15465.xx) + 1.0f.xx) * 0.5f;
                    _21580 = float2(_15478.x - _15397, _15400 - _15478.y);
                    break;
                } while(false);
                float2 _14668 = abs(_21579);
                bool2 _23486 = any(bool2(_14668.x > 4.0f.xx.x, _14668.y > 4.0f.xx.y)).xx;
                float2 _14674 = abs(_21580);
                bool2 _23488 = any(bool2(_14674.x > 4.0f.xx.x, _14674.y > 4.0f.xx.y)).xx;
                float2 _15492[3];
                _15492[0] = _5433;
                float2 _15612 = clamp(_5433, 0.0f.xx, 1.0f.xx);
                uint _15620_dummy_parameter;
                _15492[1] = _5433 - ((r_motion_tp1.Load(int3(int2(floor(_15612 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15620_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5658);
                _15492[2] = _5433 - (float2(_23486.x ? 0.0f.xx.x : _21579.x, _23486.y ? 0.0f.xx.y : _21579.y) * _5658);
                float _21586;
                float2 _21587;
                _21587 = _5433;
                _21586 = 1000000000.0f;
                float _23490;
                float2 _23492;
                float _23493;
                int _21585 = 0;
                float _21734 = -1.0f;
                for (; _21585 < 3; _21734 = _23490, _21587 = _23492, _21586 = _23493, _21585++)
                {
                    float2 _21724;
                    _21724 = _15492[_21585];
                    for (int _21723 = 0; _21723 < 30; )
                    {
                        uint _16134_dummy_parameter;
                        _21724 += (((_5433 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_21724, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16134_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5658)) - _21724) * 0.699999988079071044921875f);
                        _21723++;
                        continue;
                    }
                    float2 _16564 = clamp(_21724, 0.0f.xx, 1.0f.xx);
                    uint _16572_dummy_parameter;
                    bool _17002 = all(bool2(_21724.x > 0.0f.xx.x, _21724.y > 0.0f.xx.y));
                    bool _17008;
                    if (_17002)
                    {
                        _17008 = all(bool2(_21724.x < 1.0f.xx.x, _21724.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17008 = _17002;
                    }
                    float _21726;
                    if (_17008)
                    {
                        _21726 = length(((_21724 + ((r_motion_tp1.Load(int3(int2(floor(_16564 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16572_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5658)) - _5433) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21726 = 1000000000.0f;
                    }
                    uint _17019_dummy_parameter;
                    float _17059 = log((r_depth_tp1.Load(int3(int2(floor(_16564 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17019_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15572 = _21726 < 0.3499999940395355224609375f;
                    bool _15574 = _21586 < 0.3499999940395355224609375f;
                    bool _15584;
                    if (_15572)
                    {
                        _15584 = (!_15574) || (_17059 > _21734);
                    }
                    else
                    {
                        _15584 = _15572;
                    }
                    bool _15597;
                    if (!_15584)
                    {
                        _15597 = ((!_15572) && (!_15574)) && (_21726 < _21586);
                    }
                    else
                    {
                        _15597 = _15584;
                    }
                    _23490 = _15597 ? _17059 : _21734;
                    bool2 _23491 = _15597.xx;
                    _23492 = float2(_23491.x ? _21724.x : _21587.x, _23491.y ? _21724.y : _21587.y);
                    _23493 = _15597 ? _21726 : _21586;
                }
                float2 _17061[3];
                _17061[0] = _5433;
                float2 _21606;
                do
                {
                    bool _21596;
                    do
                    {
                        bool _17308 = all(bool2(_15612.x > 0.0f.xx.x, _15612.y > 0.0f.xx.y));
                        bool _17314;
                        if (_17308)
                        {
                            _17314 = all(bool2(_15612.x < 1.0f.xx.x, _15612.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17314 = _17308;
                        }
                        if (!_17314)
                        {
                            _21596 = false;
                            break;
                        }
                        uint _17321_dummy_parameter;
                        float4x4 _21594;
                        do
                        {
                            float4x4 _17335;
                            bool _21593;
                            do
                            {
                                _17335 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14853)
                                {
                                    _21593 = false;
                                    break;
                                }
                                uint _17369 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17369 + 32u) * 4 + 0) != 1u)
                                {
                                    _21593 = false;
                                    break;
                                }
                                uint _21590;
                                _21590 = 0u;
                                for (; _21590 < 4u; _21590++)
                                {
                                    for (uint _21591 = 0u; _21591 < 4u; )
                                    {
                                        _17335[_21590][_21591] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17369 + (_21590 * 4u)) + _21591) * 4 + 0));
                                        _21591++;
                                        continue;
                                    }
                                }
                                _21593 = true;
                                break;
                            } while(false);
                            if (_21593)
                            {
                                _21594 = _17335;
                                break;
                            }
                            _21594 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21595;
                        do
                        {
                            float _17446 = _15612.x;
                            float _17449 = 1.0f - _15612.y;
                            float4 _17460 = mul(float4((float2(_17446, _17449) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15612 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17321_dummy_parameter))))), 0)).x, 1.0f), _21594);
                            float _17462 = _17460.w;
                            if (!(_17462 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21595 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17475 = ((_17460.xy / _17462.xx) + 1.0f.xx) * 0.5f;
                            _21595 = float2(_17475.x - _17446, _17449 - _17475.y);
                            break;
                        } while(false);
                        float2 _17272 = abs(_21595);
                        if (any(bool2(_17272.x > 100000.0f.xx.x, _17272.y > 100000.0f.xx.y)))
                        {
                            _21596 = false;
                            break;
                        }
                        float _17280 = length(_21595 * _7120);
                        uint _17495_dummy_parameter;
                        bool _17294 = _17280 > ((8.0f * _7120.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17301;
                        if (_17294)
                        {
                            _17301 = length((r_motion_tp1.Load(int3(int2(floor(_15612 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17495_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7120) < (0.20000000298023223876953125f * _17280);
                        }
                        else
                        {
                            _17301 = _17294;
                        }
                        _21596 = _17301;
                        break;
                    } while(false);
                    if (_21596)
                    {
                        uint _17526_dummy_parameter;
                        _21606 = -(r_motion_tp1.Load(int3(int2(floor(_15612 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17526_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17553_dummy_parameter;
                    float2 _21605;
                    do
                    {
                        float _17572 = _15612.x;
                        float _17575 = 1.0f - _15612.y;
                        float4 _17586 = mul(float4((float2(_17572, _17575) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15612 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17553_dummy_parameter))))), 0)).x, 1.0f), _14611);
                        float _17588 = _17586.w;
                        if (!(_17588 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21605 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17601 = ((_17586.xy / _17588.xx) + 1.0f.xx) * 0.5f;
                        _21605 = float2(_17601.x - _17572, _17575 - _17601.y);
                        break;
                    } while(false);
                    float2 _17239 = abs(_21605);
                    bool2 _17243 = any(bool2(_17239.x > 4.0f.xx.x, _17239.y > 4.0f.xx.y)).xx;
                    _21606 = float2(_17243.x ? 0.0f.xx.x : _21605.x, _17243.y ? 0.0f.xx.y : _21605.y);
                    break;
                } while(false);
                _17061[1] = _5433 - (_21606 * cbFI_Timestep);
                _17061[2] = _5433 - (float2(_23488.x ? 0.0f.xx.x : _21580.x, _23488.y ? 0.0f.xx.y : _21580.y) * cbFI_Timestep);
                float _21608;
                float2 _21609;
                _21609 = _5433;
                _21608 = 1000000000.0f;
                float _23494;
                float2 _23496;
                float _23497;
                float4x4 _17849;
                float4x4 _18287;
                int _21607 = 0;
                float _21661 = -1.0f;
                for (; _21607 < 3; _21661 = _23494, _21609 = _23496, _21608 = _23497, _21607++)
                {
                    float2 _21611;
                    _21611 = _17061[_21607];
                    float2 _17658;
                    for (int _21610 = 0; _21610 < 30; _21611 = _17658, _21610++)
                    {
                        float2 _21702;
                        do
                        {
                            float2 _17738 = clamp(_21611, 0.0f.xx, 1.0f.xx);
                            bool _21692;
                            do
                            {
                                bool _17822 = all(bool2(_17738.x > 0.0f.xx.x, _17738.y > 0.0f.xx.y));
                                bool _17828;
                                if (_17822)
                                {
                                    _17828 = all(bool2(_17738.x < 1.0f.xx.x, _17738.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17828 = _17822;
                                }
                                if (!_17828)
                                {
                                    _21692 = false;
                                    break;
                                }
                                uint _17835_dummy_parameter;
                                float4x4 _21690;
                                do
                                {
                                    bool _21689;
                                    do
                                    {
                                        _17849 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14853)
                                        {
                                            _21689 = false;
                                            break;
                                        }
                                        uint _17883 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17883 + 32u) * 4 + 0) != 1u)
                                        {
                                            _21689 = false;
                                            break;
                                        }
                                        uint _21686;
                                        _21686 = 0u;
                                        for (; _21686 < 4u; _21686++)
                                        {
                                            for (uint _21687 = 0u; _21687 < 4u; )
                                            {
                                                _17849[_21686][_21687] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17883 + (_21686 * 4u)) + _21687) * 4 + 0));
                                                _21687++;
                                                continue;
                                            }
                                        }
                                        _21689 = true;
                                        break;
                                    } while(false);
                                    if (_21689)
                                    {
                                        _21690 = _17849;
                                        break;
                                    }
                                    _21690 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _21691;
                                do
                                {
                                    float _17960 = _17738.x;
                                    float _17963 = 1.0f - _17738.y;
                                    float4 _17974 = mul(float4((float2(_17960, _17963) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17738 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17835_dummy_parameter))))), 0)).x, 1.0f), _21690);
                                    float _17976 = _17974.w;
                                    if (!(_17976 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _21691 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _17989 = ((_17974.xy / _17976.xx) + 1.0f.xx) * 0.5f;
                                    _21691 = float2(_17989.x - _17960, _17963 - _17989.y);
                                    break;
                                } while(false);
                                float2 _17786 = abs(_21691);
                                if (any(bool2(_17786.x > 100000.0f.xx.x, _17786.y > 100000.0f.xx.y)))
                                {
                                    _21692 = false;
                                    break;
                                }
                                float _17794 = length(_21691 * _7120);
                                uint _18009_dummy_parameter;
                                bool _17808 = _17794 > ((8.0f * _7120.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17815;
                                if (_17808)
                                {
                                    _17815 = length((r_motion_tp1.Load(int3(int2(floor(_17738 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18009_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7120) < (0.20000000298023223876953125f * _17794);
                                }
                                else
                                {
                                    _17815 = _17808;
                                }
                                _21692 = _17815;
                                break;
                            } while(false);
                            if (_21692)
                            {
                                uint _18040_dummy_parameter;
                                _21702 = -(r_motion_tp1.Load(int3(int2(floor(_17738 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18040_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _18067_dummy_parameter;
                            float2 _21701;
                            do
                            {
                                float _18086 = _17738.x;
                                float _18089 = 1.0f - _17738.y;
                                float4 _18100 = mul(float4((float2(_18086, _18089) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17738 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18067_dummy_parameter))))), 0)).x, 1.0f), _14611);
                                float _18102 = _18100.w;
                                if (!(_18102 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21701 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18115 = ((_18100.xy / _18102.xx) + 1.0f.xx) * 0.5f;
                                _21701 = float2(_18115.x - _18086, _18089 - _18115.y);
                                break;
                            } while(false);
                            float2 _17753 = abs(_21701);
                            bool2 _17757 = any(bool2(_17753.x > 4.0f.xx.x, _17753.y > 4.0f.xx.y)).xx;
                            _21702 = float2(_17757.x ? 0.0f.xx.x : _21701.x, _17757.y ? 0.0f.xx.y : _21701.y);
                            break;
                        } while(false);
                        _17658 = _21611 + (((_5433 - (_21702 * cbFI_Timestep)) - _21611) * 0.699999988079071044921875f);
                    }
                    float2 _18176;
                    float2 _21628;
                    do
                    {
                        _18176 = clamp(_21611, 0.0f.xx, 1.0f.xx);
                        bool _21618;
                        do
                        {
                            bool _18260 = all(bool2(_18176.x > 0.0f.xx.x, _18176.y > 0.0f.xx.y));
                            bool _18266;
                            if (_18260)
                            {
                                _18266 = all(bool2(_18176.x < 1.0f.xx.x, _18176.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18266 = _18260;
                            }
                            if (!_18266)
                            {
                                _21618 = false;
                                break;
                            }
                            uint _18273_dummy_parameter;
                            float4x4 _21616;
                            do
                            {
                                bool _21615;
                                do
                                {
                                    _18287 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14853)
                                    {
                                        _21615 = false;
                                        break;
                                    }
                                    uint _18321 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18321 + 32u) * 4 + 0) != 1u)
                                    {
                                        _21615 = false;
                                        break;
                                    }
                                    uint _21612;
                                    _21612 = 0u;
                                    for (; _21612 < 4u; _21612++)
                                    {
                                        for (uint _21613 = 0u; _21613 < 4u; )
                                        {
                                            _18287[_21612][_21613] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18321 + (_21612 * 4u)) + _21613) * 4 + 0));
                                            _21613++;
                                            continue;
                                        }
                                    }
                                    _21615 = true;
                                    break;
                                } while(false);
                                if (_21615)
                                {
                                    _21616 = _18287;
                                    break;
                                }
                                _21616 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _21617;
                            do
                            {
                                float _18401 = 1.0f - _18176.y;
                                float4 _18412 = mul(float4((float2(_18176.x, _18401) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18176 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18273_dummy_parameter))))), 0)).x, 1.0f), _21616);
                                float _18414 = _18412.w;
                                if (!(_18414 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21617 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18427 = ((_18412.xy / _18414.xx) + 1.0f.xx) * 0.5f;
                                _21617 = float2(_18427.x - _18176.x, _18401 - _18427.y);
                                break;
                            } while(false);
                            float2 _18224 = abs(_21617);
                            if (any(bool2(_18224.x > 100000.0f.xx.x, _18224.y > 100000.0f.xx.y)))
                            {
                                _21618 = false;
                                break;
                            }
                            float _18232 = length(_21617 * _7120);
                            uint _18447_dummy_parameter;
                            bool _18246 = _18232 > ((8.0f * _7120.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18253;
                            if (_18246)
                            {
                                _18253 = length((r_motion_tp1.Load(int3(int2(floor(_18176 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18447_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7120) < (0.20000000298023223876953125f * _18232);
                            }
                            else
                            {
                                _18253 = _18246;
                            }
                            _21618 = _18253;
                            break;
                        } while(false);
                        if (_21618)
                        {
                            uint _18478_dummy_parameter;
                            _21628 = -(r_motion_tp1.Load(int3(int2(floor(_18176 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18478_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18505_dummy_parameter;
                        float2 _21627;
                        do
                        {
                            float _18527 = 1.0f - _18176.y;
                            float4 _18538 = mul(float4((float2(_18176.x, _18527) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18176 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18505_dummy_parameter))))), 0)).x, 1.0f), _14611);
                            float _18540 = _18538.w;
                            if (!(_18540 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21627 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18553 = ((_18538.xy / _18540.xx) + 1.0f.xx) * 0.5f;
                            _21627 = float2(_18553.x - _18176.x, _18527 - _18553.y);
                            break;
                        } while(false);
                        float2 _18191 = abs(_21627);
                        bool2 _18195 = any(bool2(_18191.x > 4.0f.xx.x, _18191.y > 4.0f.xx.y)).xx;
                        _21628 = float2(_18195.x ? 0.0f.xx.x : _21627.x, _18195.y ? 0.0f.xx.y : _21627.y);
                        break;
                    } while(false);
                    bool _18571 = all(bool2(_21611.x > 0.0f.xx.x, _21611.y > 0.0f.xx.y));
                    bool _18577;
                    if (_18571)
                    {
                        _18577 = all(bool2(_21611.x < 1.0f.xx.x, _21611.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18577 = _18571;
                    }
                    float _21640;
                    if (_18577)
                    {
                        _21640 = length(((_21611 + (_21628 * cbFI_Timestep)) - _5433) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21640 = 1000000000.0f;
                    }
                    uint _18604_dummy_parameter;
                    float _18628 = log((r_depth_tm1.Load(int3(int2(floor(_18176 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18604_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _17141 = _21640 < 0.3499999940395355224609375f;
                    bool _17143 = _21608 < 0.3499999940395355224609375f;
                    bool _17153;
                    if (_17141)
                    {
                        _17153 = (!_17143) || (_18628 > _21661);
                    }
                    else
                    {
                        _17153 = _17141;
                    }
                    bool _17166;
                    if (!_17153)
                    {
                        _17166 = ((!_17141) && (!_17143)) && (_21640 < _21608);
                    }
                    else
                    {
                        _17166 = _17153;
                    }
                    _23494 = _17166 ? _18628 : _21661;
                    bool2 _23495 = _17166.xx;
                    _23496 = float2(_23495.x ? _21611.x : _21609.x, _23495.y ? _21611.y : _21609.y);
                    _23497 = _17166 ? _21640 : _21608;
                }
                float3 _18637 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21587, 0.0f).xyz;
                float3 _18645 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21609, 0.0f).xyz;
                uint _18652_dummy_parameter;
                uint _18683_dummy_parameter;
                float _14714 = exp((_21586 * (-2.0f)) * (_21586 * 2.0f));
                float _14721 = exp((_21608 * (-2.0f)) * (_21608 * 2.0f));
                float _14734 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21609, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18683_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21587, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18652_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14748 = ((_14714 * cbFI_Timestep) * ((1.0f - _14721) + ((_14721 * 2.0f) * _14734))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14758 = 1.0f - _14734;
                float _14765 = ((_14721 * _5658) * ((1.0f - _14714) + ((_14714 * 2.0f) * _14758))) + (9.9999997473787516355514526367188e-05f * _5658);
                float _14774 = (((_14714 * _14721) * 4.0f) * _14734) * _14758;
                float _14792 = (_14774 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18645 - _18637, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14774)) * max(_14714, _14721));
                if (_6806 == 30u)
                {
                    _21754 = _14792;
                    _21753 = _18637;
                    break;
                }
                if (_6806 == 31u)
                {
                    _21754 = _14792;
                    _21753 = _18645;
                    break;
                }
                if (_6806 == 32u)
                {
                    _21754 = _14792;
                    _21753 = float3(_14714, _14721, _14734);
                    break;
                }
                _21754 = _14792;
                _21753 = ((_18637 * _14748) + (_18645 * _14765)) / (_14748 + _14765).xxx;
                break;
            } while(false);
            _23192 = _21754;
            _23116 = _21753;
        }
        else
        {
            _23192 = 1.0f;
            _23116 = _23117;
        }
        uint _7136 = cbFI_pad0 & 255u;
        bool _22923;
        float3 _23115;
        if (_7136 != 0u)
        {
            float3 _7141 = r_present_backbuffer.Load(int3(_4934, 0)).xyz;
            float3 _7145 = r_current_interpolation_source.Load(int3(_4934, 0)).xyz;
            float3 _7149 = abs(_7141 - _7145);
            float3 _21763;
            if (_7136 == 2u)
            {
                _21763 = (abs(_7145) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21763 = 0.000244140625f.xxx;
            }
            bool _7165 = any(bool3(_7149.x > _21763.x, _7149.y > _21763.y, _7149.z > _21763.z));
            bool3 _23498 = _7165.xxx;
            _23115 = float3(_23498.x ? _7141.x : _23116.x, _23498.y ? _7141.y : _23116.y, _23498.z ? _7141.z : _23116.z);
            _22923 = _7165;
        }
        else
        {
            _23115 = _23116;
            _22923 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18721;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18721);
        }
        float3 _23097;
        if (_6806 == 1u)
        {
            _23097 = lerp(_8638, _8646, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _23098;
            if (_6806 == 2u)
            {
                _23098 = lerp(_8654, _8662, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _23099;
                if (_6806 == 3u)
                {
                    _23099 = float(_22923).xxx;
                }
                else
                {
                    float3 _23100;
                    if (_6806 == 4u)
                    {
                        _23100 = float3(((_19656 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _23101;
                        if (_6806 == 5u)
                        {
                            _23101 = float3(((_7933 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _23102;
                            if (_6806 == 6u)
                            {
                                _23102 = float3(_21162.xy, _21162.z + _21162.w);
                            }
                            else
                            {
                                float3 _23103;
                                if (_6806 == 7u)
                                {
                                    _23103 = r_current_interpolation_source.Load(int3(_4934, 0)).xyz;
                                }
                                else
                                {
                                    float3 _23104;
                                    if (_6806 == 8u)
                                    {
                                        _23104 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5433, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _23105;
                                        if (_6810)
                                        {
                                            uint _18743_dummy_parameter;
                                            uint _18775_dummy_parameter;
                                            _23105 = float3(log((r_depth_tp1.Load(int3(int2(floor(_5433 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18743_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_5433 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18775_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _23106;
                                            if (_6813)
                                            {
                                                _23106 = _8654;
                                            }
                                            else
                                            {
                                                float3 _23107;
                                                if (_6806 == 20u)
                                                {
                                                    _23107 = _8638;
                                                }
                                                else
                                                {
                                                    float3 _23108;
                                                    if (_6806 == 21u)
                                                    {
                                                        _23108 = _8646;
                                                    }
                                                    else
                                                    {
                                                        float3 _23109;
                                                        if (_6806 == 22u)
                                                        {
                                                            _23109 = _8662;
                                                        }
                                                        else
                                                        {
                                                            float3 _23110;
                                                            if (_6806 == 18u)
                                                            {
                                                                _23110 = _22371;
                                                            }
                                                            else
                                                            {
                                                                float3 _23111;
                                                                if (_6806 == 19u)
                                                                {
                                                                    _23111 = _22068;
                                                                }
                                                                else
                                                                {
                                                                    float3 _23112;
                                                                    if (_6806 == 23u)
                                                                    {
                                                                        _23112 = _21771;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _23113;
                                                                        if (_6806 == 24u)
                                                                        {
                                                                            uint _7309 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7314 = float(rw_nfru_diagnostics.Load<uint>((_7309 + 35u) * 4 + 0));
                                                                            float _21764;
                                                                            if (_7314 > 0.0f)
                                                                            {
                                                                                _21764 = float(rw_nfru_diagnostics.Load<uint>((_7309 + 34u) * 4 + 0)) / _7314;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21764 = 0.0f;
                                                                            }
                                                                            _23113 = float3(float(rw_nfru_diagnostics.Load<uint>((_7309 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7309 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21764);
                                                                        }
                                                                        else
                                                                        {
                                                                            _23113 = _23115;
                                                                        }
                                                                        _23112 = _23113;
                                                                    }
                                                                    _23111 = _23112;
                                                                }
                                                                _23110 = _23111;
                                                            }
                                                            _23109 = _23110;
                                                        }
                                                        _23108 = _23109;
                                                    }
                                                    _23107 = _23108;
                                                }
                                                _23106 = _23107;
                                            }
                                            _23105 = _23106;
                                        }
                                        _23104 = _23105;
                                    }
                                    _23103 = _23104;
                                }
                                _23102 = _23103;
                            }
                            _23101 = _23102;
                        }
                        _23100 = _23101;
                    }
                    _23099 = _23100;
                }
                _23098 = _23099;
            }
            _23097 = _23098;
        }
        float3 _23096;
        if ((_6806 >= 9u) && (_6806 <= 11u))
        {
            uint _7374 = 64u + uint((_19879.y * cbFI_MvDepthLaneSize.x) + _19879.x);
            uint _7378 = rw_nfru_diagnostics.Load<uint>(_7374 * 4 + 0) & 15u;
            float3 _23130;
            if (_6806 == 10u)
            {
                float3 _23095;
                if ((rw_nfru_diagnostics.Load<uint>(_7374 * 4 + 0) & 32u) != 0u)
                {
                    _23095 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _23094;
                    if ((rw_nfru_diagnostics.Load<uint>(_7374 * 4 + 0) & 16u) != 0u)
                    {
                        _23094 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7399 = ((rw_nfru_diagnostics.Load<uint>(_7374 * 4 + 0) & 64u) != 0u).xxx;
                        _23094 = float3(_7399.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7399.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7399.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _23095 = _23094;
                }
                _23130 = _23095;
            }
            else
            {
                float3 _23131;
                if (_6806 == 11u)
                {
                    uint _7412 = (rw_nfru_diagnostics.Load<uint>(_7374 * 4 + 0) >> 8u) & 15u;
                    uint _7415 = (rw_nfru_diagnostics.Load<uint>(_7374 * 4 + 0) >> 12u) & 15u;
                    float3 _23087;
                    if ((_7378 == 2u) || (_7378 == 3u))
                    {
                        _23087 = _4633[_7378];
                    }
                    else
                    {
                        bool _7427 = _7412 == 3u;
                        bool _7429 = _7415 == 3u;
                        float3 _23088;
                        if (_7427 && _7429)
                        {
                            _23088 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _23089;
                            if (_7427)
                            {
                                _23089 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _23090;
                                if (_7429)
                                {
                                    _23090 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _23091;
                                    if ((_7412 == 4u) || (_7415 == 4u))
                                    {
                                        _23091 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _23092;
                                        if ((_7412 == 1u) || (_7415 == 1u))
                                        {
                                            _23092 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23500 = (_7378 == 1u).xxx;
                                            _23092 = float3(_23500.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23500.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23500.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _23091 = _23092;
                                    }
                                    _23090 = _23091;
                                }
                                _23089 = _23090;
                            }
                            _23088 = _23089;
                        }
                        _23087 = _23088;
                    }
                    _23131 = _23087;
                }
                else
                {
                    _23131 = _4633[min(_7378, 7u)];
                }
                _23130 = _23131;
            }
            _23096 = _23130;
        }
        else
        {
            _23096 = _23097;
        }
        float4 _23134;
        if ((_6806 >= 14u) && (_6806 <= 16u))
        {
            float2 _23132;
            if (_6806 == 14u)
            {
                uint _7485_dummy_parameter;
                uint _7491_dummy_parameter;
                _23132 = r_flow_tm1.Load(int3(clamp(int2(floor(_5433 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7485_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7491_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _23133;
                if (_6806 == 16u)
                {
                    uint _18851 = r_warped_flow_qdata_tm1.Load(int3(_5449, 0)).x & 2147483647u;
                    uint _18883 = uint(max((int((_18851 >> 16u) & 15u) - 6), 0));
                    _23133 = ((float2(float((1 - (2 * int((_18851 >> 15u) & 1u))) * int(((_18851 >> uint(7)) & 127u) << _18883)), float((1 - (2 * int((_18851 >> 14u) & 1u))) * int((_18851 & 127u) << _18883))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _23133 = _7933 * float2(cbFI_DisplaySize);
                }
                _23132 = _23133;
            }
            uint2 _7524 = uint2(clamp(round(_23132 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7526 = _7524.x;
            uint _7533 = _7524.y;
            _23134 = float4(float(_7526 & 255u), float((_7526 >> 8u) | ((_7533 & 15u) << 4u)), float(_7533 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _23135;
            if (_6806 == 17u)
            {
                _23135 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5449, 0)).x != 0u), _5893, 0.0f, 1.0f);
            }
            else
            {
                _23135 = float4(_23096, 1.0f);
            }
            _23134 = _23135;
        }
        rw_output[_4934] = _23134.xyz;
        if (_7116)
        {
            uint _18928 = uint((_4934.y * cbFI_DisplaySize.x) + _4934.x) * 2u;
            rw_nfru_select.Store<uint>(_18928 * 4 + 0, spvPackHalf2x16(_23134.xy));
            rw_nfru_select.Store<uint>((_18928 + 1u) * 4 + 0, spvPackHalf2x16(float2(_23134.z, (_22923 || (_6806 != 0u)) ? 2.0f : _23192)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7591 = ((uint(_4934.y) * uint(cbFI_DisplaySize.x)) + uint(_4934.x)) * 6u;
            uint _18954 = spvPackHalf2x16(clamp(_8637.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7591 * 4 + 0, (((_18954 & 32767u) >> 4u) | ((((_18954 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8637.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18989 = spvPackHalf2x16(clamp(_8645.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7591 + 1u) * 4 + 0, (((_18989 & 32767u) >> 4u) | ((((_18989 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8645.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19024 = spvPackHalf2x16(clamp(_8653.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7591 + 2u) * 4 + 0, (((_19024 & 32767u) >> 4u) | ((((_19024 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8653.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19059 = spvPackHalf2x16(clamp(_8661.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7591 + 3u) * 4 + 0, (((_19059 & 32767u) >> 4u) | ((((_19059 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8661.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19086 = r_current_interpolation_source.Load(int3(_4934, 0));
            uint _19100 = spvPackHalf2x16(clamp(_19086.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7591 + 4u) * 4 + 0, (((_19100 & 32767u) >> 4u) | ((((_19100 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19086.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _23211;
            if (_22923 || (_6806 != 0u))
            {
                _23211 = 4294967295u;
            }
            else
            {
                uint _19135 = spvPackHalf2x16(clamp(_23134.xy, 0.0f.xx, 65000.0f.xx));
                _23211 = (((_19135 & 32767u) >> 4u) | ((((_19135 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_23134.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7591 + 5u) * 4 + 0, _23211);
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
