static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19862;

static const int2 _1243[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1252[5] = { 2, 4, 7, 11, 16 };
static const float3 _4745[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _5045 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_5045.x >= cbFI_DisplaySize.x, _5045.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_5045] = float4(r_present_backbuffer.Load(int3(_5045, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7898 = cbFI_DisplaySize - int2(1, 1);
                int2 _7899 = clamp(_5045, int2(0, 0), _7898);
                uint _7909 = uint((_7899.y * cbFI_DisplaySize.x) + _7899.x) * 2u;
                uint _7912 = rw_nfru_select.Load<uint>(_7909 * 4 + 0);
                float2 _7913 = spvUnpackHalf2x16(_7912);
                uint _7917 = rw_nfru_select.Load<uint>((_7909 + 1u) * 4 + 0);
                float2 _7918 = spvUnpackHalf2x16(_7917);
                float _7919 = _7913.x;
                float _7921 = _7918.x;
                if (_7918.y > 1.5f)
                {
                    rw_output[_5045] = float4(_7919, _7913.y, _7921, 1.0f).xyz;
                    break;
                }
                int _23536;
                float _23537;
                float3 _23538;
                float _23539;
                float _23540;
                _23540 = 0.0f;
                _23539 = 0.0f;
                _23538 = 0.0f.xxx;
                _23537 = 0.0f;
                _23536 = -2;
                float3 _23543;
                float _23544;
                float _23545;
                float _23546;
                for (; _23536 <= 2; _23540 = _23546, _23539 = _23545, _23538 = _23543, _23537 = _23544, _23536++)
                {
                    _23546 = _23540;
                    _23545 = _23539;
                    _23544 = _23537;
                    _23543 = _23538;
                    for (int _23541 = -2; _23541 <= 2; )
                    {
                        float _7815 = float((_23541 * _23541) + (_23536 * _23536));
                        float _7820 = exp(_7815 * (-0.319999992847442626953125f));
                        int2 _7825 = int2(_23541, _23536);
                        int2 _7935 = clamp(_5045 + (_7825 * int2(2, 2)), int2(0, 0), _7898);
                        uint _7945 = uint((_7935.y * cbFI_DisplaySize.x) + _7935.x) * 2u;
                        float _7842 = exp(_7815 * (-0.5f));
                        int2 _7967 = clamp(_5045 + (_7825 * int2(6, 6)), int2(0, 0), _7898);
                        _23546 += _7842;
                        _23545 += (_7842 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7967.y * cbFI_DisplaySize.x) + _7967.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23544 += _7820;
                        _23543 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7945 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7945 + 1u) * 4 + 0)).x, _19862).xyz * _7820);
                        _23541++;
                        continue;
                    }
                }
                float3 _7872 = _23538 / _23537.xxx;
                rw_output[_5045] = float4(_7872 + ((float4(_7919, _7913.y, _7921, _7918.y).xyz - _7872) * clamp(_23539 / _23540, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5544 = (float2(_5045) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5546 = float2(cbFI_MvDepthLaneSize);
        int2 _5555 = int2(floor(_5544 * _5546));
        int2 _5560 = int2(floor(_5544 * float2(cbFI_FlowLaneSize)));
        float4 _8038 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5544 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _8044 = r_warped_filled_flow_tm1.Load(int3(_5560, 0)).xy;
        float2 _8050 = r_warped_filled_motion_tp1.Load(int3(_5555, 0)).xy;
        bool _8072 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19863;
        if (_8072)
        {
            float _8085 = ((2.0f * _5544.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19863 = float2(atan(_8085) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5544.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_8085 * _8085))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19863 = _5544;
        }
        bool _5581 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19884;
        bool _20026;
        int2 _20107;
        float3 _22626;
        if (_5581)
        {
            float _19865;
            float _19867;
            _19867 = 2.0f;
            _19865 = -1.0f;
            uint _5142[9];
            float _23547;
            float _23550;
            for (int _19864 = 0; _19864 < 9; _19867 = _23550, _19865 = _23547, _19864++)
            {
                _5142[_19864] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5555 + int2((_19864 % 3) - 1, (_19864 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_5142[_19864] != 0u)
                {
                    float _23531;
                    if (_5142[_19864] == 0u)
                    {
                        _23531 = -1.0f;
                    }
                    else
                    {
                        _23531 = float((_5142[_19864] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23550 = min(_19867, _23531);
                    _23547 = max(_19865, _23531);
                }
                else
                {
                    _23550 = _19867;
                    _23547 = _19865;
                }
            }
            float _5627 = float(_19865 >= 0.0f);
            float3 _19400 = 0.0f.xxx;
            _19400.y = _5627;
            float2 _19885;
            bool _20027;
            int2 _20108;
            float3 _22627;
            if ((_19865 - _19867) > 0.0199999995529651641845703125f)
            {
                float _19873;
                int2 _19874;
                float2 _19875;
                int2 _19877;
                float2 _19883;
                _19883 = _8050;
                _19877 = _5555;
                _19875 = _8050;
                _19874 = _5555;
                _19873 = -1.0f;
                float _23555;
                int2 _23559;
                float2 _23570;
                int2 _23581;
                float2 _23614;
                float _23739;
                int _19872 = 0;
                float _23512 = 1000000000.0f;
                for (; _19872 < 9; _23512 = _23739, _19883 = _23614, _19877 = _23581, _19875 = _23570, _19874 = _23559, _19873 = _23555, _19872++)
                {
                    if (_5142[_19872] == 0u)
                    {
                        _23739 = _23512;
                        _23614 = _19883;
                        _23581 = _19877;
                        _23570 = _19875;
                        _23559 = _19874;
                        _23555 = _19873;
                        continue;
                    }
                    int2 _5662 = clamp(_5555 + int2((_19872 % 3) - 1, (_19872 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8160 = _5142[_19872] & 2147483647u;
                    uint _8192 = uint(max((int((_8160 >> 16u) & 15u) - 6), 0));
                    float2 _5668 = (float2(float((1 - (2 * int((_8160 >> 15u) & 1u))) * int(((_8160 >> uint(7)) & 127u) << _8192)), float((1 - (2 * int((_8160 >> 14u) & 1u))) * int((_8160 & 127u) << _8192))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23498;
                    if (_5142[_19872] == 0u)
                    {
                        _23498 = -1.0f;
                    }
                    else
                    {
                        _23498 = float((_5142[_19872] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5673 = _23498 - 0.100000001490116119384765625f;
                    float2 _23499;
                    if (_8072)
                    {
                        float2 _8269 = clamp((((_19863 + (_5668 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8272 = tan(_8269.x);
                        _23499 = (float2(_8272 / cbFI_DeviceToViewDepth.z, (tan(_8269.y) * sqrt(1.0f + (_8272 * _8272))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23499 = _19863 + (_5668 * cbFI_Timestep);
                    }
                    float _5680 = cbFI_Timestep - 1.0f;
                    float2 _23500;
                    if (_8072)
                    {
                        float2 _8340 = clamp((((_19863 + (_5668 * _5680)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8343 = tan(_8340.x);
                        _23500 = (float2(_8343 / cbFI_DeviceToViewDepth.z, (tan(_8340.y) * sqrt(1.0f + (_8343 * _8343))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23500 = _19863 + (_5668 * _5680);
                    }
                    bool _8376 = all(bool2(_23499.x > 0.0f.xx.x, _23499.y > 0.0f.xx.y));
                    bool _8382;
                    if (_8376)
                    {
                        _8382 = all(bool2(_23499.x < 1.0f.xx.x, _23499.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8382 = _8376;
                    }
                    float _23503;
                    if (_8382)
                    {
                        uint _8389_dummy_parameter;
                        _23503 = max((_5673 - (log((r_depth_tm1.Load(int3(int2(floor(_23499 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8389_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23503 = 0.0f;
                    }
                    bool _8419 = all(bool2(_23500.x > 0.0f.xx.x, _23500.y > 0.0f.xx.y));
                    bool _8425;
                    if (_8419)
                    {
                        _8425 = all(bool2(_23500.x < 1.0f.xx.x, _23500.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8425 = _8419;
                    }
                    float _23504;
                    if (_8425)
                    {
                        uint _8432_dummy_parameter;
                        _23504 = _23503 + max((_5673 - (log((r_depth_tp1.Load(int3(int2(floor(_23500 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8432_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23504 = _23503;
                    }
                    float _23556;
                    int2 _23560;
                    float2 _23571;
                    int2 _23582;
                    float2 _23615;
                    float _23740;
                    if (_23504 == 0.0f)
                    {
                        bool _5715 = _5673 > _19873;
                        bool2 _23748 = _5715.xx;
                        _23740 = _23512;
                        _23615 = float2(_23748.x ? _5668.x : _19883.x, _23748.y ? _5668.y : _19883.y);
                        _23582 = int2(_23748.x ? _5662.x : _19877.x, _23748.y ? _5662.y : _19877.y);
                        _23571 = _19875;
                        _23560 = _19874;
                        _23556 = _5715 ? _5673 : _19873;
                    }
                    else
                    {
                        bool _5724 = _23504 < _23512;
                        bool2 _23744 = _5724.xx;
                        _23740 = _5724 ? _23504 : _23512;
                        _23615 = _19883;
                        _23582 = _19877;
                        _23571 = float2(_23744.x ? _5668.x : _19875.x, _23744.y ? _5668.y : _19875.y);
                        _23560 = int2(_23744.x ? _5662.x : _19874.x, _23744.y ? _5662.y : _19874.y);
                        _23556 = _19873;
                    }
                    _23739 = _23740;
                    _23614 = _23615;
                    _23581 = _23582;
                    _23570 = _23571;
                    _23559 = _23560;
                    _23555 = _23556;
                }
                bool _5736 = _19873 < 0.0f;
                bool2 _23754 = _5736.xx;
                int2 _23757 = int2(_23754.x ? _19874.x : _19877.x, _23754.y ? _19874.y : _19877.y);
                _22627 = float3(1.0f, _5627, float(any(bool2(_23757.x != _5555.x, _23757.y != _5555.y))));
                _20108 = _23757;
                _20027 = _5736 ? false : true;
                _19885 = float2(_23754.x ? _19875.x : _19883.x, _23754.y ? _19875.y : _19883.y);
            }
            else
            {
                _22627 = _19400;
                _20108 = _5555;
                _20027 = false;
                _19885 = _8050;
            }
            _22626 = _22627;
            _20107 = _20108;
            _20026 = _20027;
            _19884 = _19885;
        }
        else
        {
            _22626 = 0.0f.xxx;
            _20107 = _5555;
            _20026 = false;
            _19884 = _8050;
        }
        float2 _19886;
        if (_8072)
        {
            float2 _8497 = clamp((((_19863 + (_19884 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8500 = tan(_8497.x);
            _19886 = (float2(_8500 / cbFI_DeviceToViewDepth.z, (tan(_8497.y) * sqrt(1.0f + (_8500 * _8500))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19886 = _19863 + (_19884 * cbFI_Timestep);
        }
        float _5759 = cbFI_Timestep - 1.0f;
        float2 _19888;
        if (_8072)
        {
            float2 _8568 = clamp((((_19863 + (_19884 * _5759)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8571 = tan(_8568.x);
            _19888 = (float2(_8571 / cbFI_DeviceToViewDepth.z, (tan(_8568.y) * sqrt(1.0f + (_8571 * _8571))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19888 = _19863 + (_19884 * _5759);
        }
        float _5764 = -cbFI_Timestep;
        float2 _19889;
        if (_8072)
        {
            float2 _8639 = clamp((((_19863 + (_8044 * _5764)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8642 = tan(_8639.x);
            _19889 = (float2(_8642 / cbFI_DeviceToViewDepth.z, (tan(_8639.y) * sqrt(1.0f + (_8642 * _8642))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19889 = _19863 + (_8044 * _5764);
        }
        float _5769 = 1.0f - cbFI_Timestep;
        float2 _19890;
        if (_8072)
        {
            float2 _8710 = clamp((((_19863 + (_8044 * _5769)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8713 = tan(_8710.x);
            _19890 = (float2(_8713 / cbFI_DeviceToViewDepth.z, (tan(_8710.y) * sqrt(1.0f + (_8713 * _8713))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19890 = _19863 + (_8044 * _5769);
        }
        float4 _8748 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19886, 0.0f);
        float3 _8749 = _8748.xyz;
        float4 _8756 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19888, 0.0f);
        float3 _8757 = _8756.xyz;
        float4 _8764 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19889, 0.0f);
        float3 _8765 = _8764.xyz;
        float4 _8772 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19890, 0.0f);
        float3 _8773 = _8772.xyz;
        float4 _8787 = exp(_8038 - max(max(max(_8038.x, _8038.y), _8038.z), _8038.w).xxxx);
        float4 _8794 = _8787 / (dot(_8787, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5785 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _20097;
        float _21405;
        if (_5785)
        {
            float2 _5791 = 0.5f.xx / _5546;
            float _5794 = _5791.x;
            float _5795 = -_5794;
            float _5797 = _5791.y;
            float _5798 = -_5797;
            float2 _5800 = _5544 + float2(_5795, _5798);
            float2 _5802 = float2(cbFI_DisplaySize);
            bool _19907;
            do
            {
                bool _8874 = all(bool2(_5800.x > 0.0f.xx.x, _5800.y > 0.0f.xx.y));
                bool _8880;
                if (_8874)
                {
                    _8880 = all(bool2(_5800.x < 1.0f.xx.x, _5800.y < 1.0f.xx.y));
                }
                else
                {
                    _8880 = _8874;
                }
                if (!_8880)
                {
                    _19907 = false;
                    break;
                }
                uint _8887_dummy_parameter;
                float4x4 _19905;
                do
                {
                    float4x4 _8901;
                    bool _19904;
                    do
                    {
                        _8901 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19904 = false;
                            break;
                        }
                        uint _8935 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8935 + 32u) * 4 + 0) != 1u)
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
                                _8901[_19901][_19902] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8935 + (_19901 * 4u)) + _19902) * 4 + 0));
                                _19902++;
                                continue;
                            }
                        }
                        _19904 = true;
                        break;
                    } while(false);
                    if (_19904)
                    {
                        _19905 = _8901;
                        break;
                    }
                    _19905 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19906;
                do
                {
                    float _9012 = _5800.x;
                    float _9015 = 1.0f - _5800.y;
                    float4 _9026 = mul(float4((float2(_9012, _9015) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5800 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8887_dummy_parameter))))), 0)).x, 1.0f), _19905);
                    float _9028 = _9026.w;
                    if (!(_9028 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19906 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9041 = ((_9026.xy / _9028.xx) + 1.0f.xx) * 0.5f;
                    _19906 = float2(_9041.x - _9012, _9015 - _9041.y);
                    break;
                } while(false);
                float2 _8838 = abs(_19906);
                if (any(bool2(_8838.x > 100000.0f.xx.x, _8838.y > 100000.0f.xx.y)))
                {
                    _19907 = false;
                    break;
                }
                float _8846 = length(_19906 * _5802);
                uint _9061_dummy_parameter;
                bool _8860 = _8846 > ((8.0f * _5802.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8867;
                if (_8860)
                {
                    _8867 = length((r_motion_tp1.Load(int3(int2(floor(_5800 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9061_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5802) < (0.20000000298023223876953125f * _8846);
                }
                else
                {
                    _8867 = _8860;
                }
                _19907 = _8867;
                break;
            } while(false);
            float2 _5812 = _5544 + float2(_5794, _5798);
            bool _19914;
            do
            {
                bool _9147 = all(bool2(_5812.x > 0.0f.xx.x, _5812.y > 0.0f.xx.y));
                bool _9153;
                if (_9147)
                {
                    _9153 = all(bool2(_5812.x < 1.0f.xx.x, _5812.y < 1.0f.xx.y));
                }
                else
                {
                    _9153 = _9147;
                }
                if (!_9153)
                {
                    _19914 = false;
                    break;
                }
                uint _9160_dummy_parameter;
                float4x4 _19912;
                do
                {
                    float4x4 _9174;
                    bool _19911;
                    do
                    {
                        _9174 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19911 = false;
                            break;
                        }
                        uint _9208 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9208 + 32u) * 4 + 0) != 1u)
                        {
                            _19911 = false;
                            break;
                        }
                        uint _19908;
                        _19908 = 0u;
                        for (; _19908 < 4u; _19908++)
                        {
                            for (uint _19909 = 0u; _19909 < 4u; )
                            {
                                _9174[_19908][_19909] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9208 + (_19908 * 4u)) + _19909) * 4 + 0));
                                _19909++;
                                continue;
                            }
                        }
                        _19911 = true;
                        break;
                    } while(false);
                    if (_19911)
                    {
                        _19912 = _9174;
                        break;
                    }
                    _19912 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19913;
                do
                {
                    float _9285 = _5812.x;
                    float _9288 = 1.0f - _5812.y;
                    float4 _9299 = mul(float4((float2(_9285, _9288) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5812 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9160_dummy_parameter))))), 0)).x, 1.0f), _19912);
                    float _9301 = _9299.w;
                    if (!(_9301 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19913 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9314 = ((_9299.xy / _9301.xx) + 1.0f.xx) * 0.5f;
                    _19913 = float2(_9314.x - _9285, _9288 - _9314.y);
                    break;
                } while(false);
                float2 _9111 = abs(_19913);
                if (any(bool2(_9111.x > 100000.0f.xx.x, _9111.y > 100000.0f.xx.y)))
                {
                    _19914 = false;
                    break;
                }
                float _9119 = length(_19913 * _5802);
                uint _9334_dummy_parameter;
                bool _9133 = _9119 > ((8.0f * _5802.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9140;
                if (_9133)
                {
                    _9140 = length((r_motion_tp1.Load(int3(int2(floor(_5812 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9334_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5802) < (0.20000000298023223876953125f * _9119);
                }
                else
                {
                    _9140 = _9133;
                }
                _19914 = _9140;
                break;
            } while(false);
            float2 _5825 = _5544 + float2(_5795, _5797);
            bool _19921;
            do
            {
                bool _9420 = all(bool2(_5825.x > 0.0f.xx.x, _5825.y > 0.0f.xx.y));
                bool _9426;
                if (_9420)
                {
                    _9426 = all(bool2(_5825.x < 1.0f.xx.x, _5825.y < 1.0f.xx.y));
                }
                else
                {
                    _9426 = _9420;
                }
                if (!_9426)
                {
                    _19921 = false;
                    break;
                }
                uint _9433_dummy_parameter;
                float4x4 _19919;
                do
                {
                    float4x4 _9447;
                    bool _19918;
                    do
                    {
                        _9447 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19918 = false;
                            break;
                        }
                        uint _9481 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9481 + 32u) * 4 + 0) != 1u)
                        {
                            _19918 = false;
                            break;
                        }
                        uint _19915;
                        _19915 = 0u;
                        for (; _19915 < 4u; _19915++)
                        {
                            for (uint _19916 = 0u; _19916 < 4u; )
                            {
                                _9447[_19915][_19916] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9481 + (_19915 * 4u)) + _19916) * 4 + 0));
                                _19916++;
                                continue;
                            }
                        }
                        _19918 = true;
                        break;
                    } while(false);
                    if (_19918)
                    {
                        _19919 = _9447;
                        break;
                    }
                    _19919 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19920;
                do
                {
                    float _9558 = _5825.x;
                    float _9561 = 1.0f - _5825.y;
                    float4 _9572 = mul(float4((float2(_9558, _9561) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5825 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9433_dummy_parameter))))), 0)).x, 1.0f), _19919);
                    float _9574 = _9572.w;
                    if (!(_9574 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19920 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9587 = ((_9572.xy / _9574.xx) + 1.0f.xx) * 0.5f;
                    _19920 = float2(_9587.x - _9558, _9561 - _9587.y);
                    break;
                } while(false);
                float2 _9384 = abs(_19920);
                if (any(bool2(_9384.x > 100000.0f.xx.x, _9384.y > 100000.0f.xx.y)))
                {
                    _19921 = false;
                    break;
                }
                float _9392 = length(_19920 * _5802);
                uint _9607_dummy_parameter;
                bool _9406 = _9392 > ((8.0f * _5802.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9413;
                if (_9406)
                {
                    _9413 = length((r_motion_tp1.Load(int3(int2(floor(_5825 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9607_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5802) < (0.20000000298023223876953125f * _9392);
                }
                else
                {
                    _9413 = _9406;
                }
                _19921 = _9413;
                break;
            } while(false);
            float2 _5837 = _5544 + _5791;
            bool _19928;
            do
            {
                bool _9693 = all(bool2(_5837.x > 0.0f.xx.x, _5837.y > 0.0f.xx.y));
                bool _9699;
                if (_9693)
                {
                    _9699 = all(bool2(_5837.x < 1.0f.xx.x, _5837.y < 1.0f.xx.y));
                }
                else
                {
                    _9699 = _9693;
                }
                if (!_9699)
                {
                    _19928 = false;
                    break;
                }
                uint _9706_dummy_parameter;
                float4x4 _19926;
                do
                {
                    float4x4 _9720;
                    bool _19925;
                    do
                    {
                        _9720 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19925 = false;
                            break;
                        }
                        uint _9754 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9754 + 32u) * 4 + 0) != 1u)
                        {
                            _19925 = false;
                            break;
                        }
                        uint _19922;
                        _19922 = 0u;
                        for (; _19922 < 4u; _19922++)
                        {
                            for (uint _19923 = 0u; _19923 < 4u; )
                            {
                                _9720[_19922][_19923] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9754 + (_19922 * 4u)) + _19923) * 4 + 0));
                                _19923++;
                                continue;
                            }
                        }
                        _19925 = true;
                        break;
                    } while(false);
                    if (_19925)
                    {
                        _19926 = _9720;
                        break;
                    }
                    _19926 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19927;
                do
                {
                    float _9831 = _5837.x;
                    float _9834 = 1.0f - _5837.y;
                    float4 _9845 = mul(float4((float2(_9831, _9834) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5837 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9706_dummy_parameter))))), 0)).x, 1.0f), _19926);
                    float _9847 = _9845.w;
                    if (!(_9847 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19927 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9860 = ((_9845.xy / _9847.xx) + 1.0f.xx) * 0.5f;
                    _19927 = float2(_9860.x - _9831, _9834 - _9860.y);
                    break;
                } while(false);
                float2 _9657 = abs(_19927);
                if (any(bool2(_9657.x > 100000.0f.xx.x, _9657.y > 100000.0f.xx.y)))
                {
                    _19928 = false;
                    break;
                }
                float _9665 = length(_19927 * _5802);
                uint _9880_dummy_parameter;
                bool _9679 = _9665 > ((8.0f * _5802.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9686;
                if (_9679)
                {
                    _9686 = length((r_motion_tp1.Load(int3(int2(floor(_5837 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9880_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5802) < (0.20000000298023223876953125f * _9665);
                }
                else
                {
                    _9686 = _9679;
                }
                _19928 = _9686;
                break;
            } while(false);
            float _5843 = 0.25f * (((float(_19907) + float(_19914)) + float(_19921)) + float(_19928));
            float4 _20098;
            if (_5843 < 1.0f)
            {
                bool _19935;
                do
                {
                    bool _9966 = all(bool2(_19886.x > 0.0f.xx.x, _19886.y > 0.0f.xx.y));
                    bool _9972;
                    if (_9966)
                    {
                        _9972 = all(bool2(_19886.x < 1.0f.xx.x, _19886.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9972 = _9966;
                    }
                    if (!_9972)
                    {
                        _19935 = false;
                        break;
                    }
                    uint _9979_dummy_parameter;
                    float4x4 _19933;
                    do
                    {
                        float4x4 _9993;
                        bool _19932;
                        do
                        {
                            _9993 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19932 = false;
                                break;
                            }
                            uint _10027 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10027 + 32u) * 4 + 0) != 1u)
                            {
                                _19932 = false;
                                break;
                            }
                            uint _19929;
                            _19929 = 0u;
                            for (; _19929 < 4u; _19929++)
                            {
                                for (uint _19930 = 0u; _19930 < 4u; )
                                {
                                    _9993[_19929][_19930] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10027 + (_19929 * 4u)) + _19930) * 4 + 0));
                                    _19930++;
                                    continue;
                                }
                            }
                            _19932 = true;
                            break;
                        } while(false);
                        if (_19932)
                        {
                            _19933 = _9993;
                            break;
                        }
                        _19933 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19934;
                    do
                    {
                        float _10107 = 1.0f - _19886.y;
                        float4 _10118 = mul(float4((float2(_19886.x, _10107) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19886 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9979_dummy_parameter))))), 0)).x, 1.0f), _19933);
                        float _10120 = _10118.w;
                        if (!(_10120 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19934 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10133 = ((_10118.xy / _10120.xx) + 1.0f.xx) * 0.5f;
                        _19934 = float2(_10133.x - _19886.x, _10107 - _10133.y);
                        break;
                    } while(false);
                    float2 _9930 = abs(_19934);
                    if (any(bool2(_9930.x > 100000.0f.xx.x, _9930.y > 100000.0f.xx.y)))
                    {
                        _19935 = false;
                        break;
                    }
                    float _9938 = length(_19934 * _5802);
                    uint _10153_dummy_parameter;
                    bool _9952 = _9938 > ((8.0f * _5802.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9959;
                    if (_9952)
                    {
                        _9959 = length((r_motion_tp1.Load(int3(int2(floor(_19886 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10153_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5802) < (0.20000000298023223876953125f * _9938);
                    }
                    else
                    {
                        _9959 = _9952;
                    }
                    _19935 = _9959;
                    break;
                } while(false);
                bool _19942;
                do
                {
                    bool _10239 = all(bool2(_19888.x > 0.0f.xx.x, _19888.y > 0.0f.xx.y));
                    bool _10245;
                    if (_10239)
                    {
                        _10245 = all(bool2(_19888.x < 1.0f.xx.x, _19888.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10245 = _10239;
                    }
                    if (!_10245)
                    {
                        _19942 = false;
                        break;
                    }
                    uint _10252_dummy_parameter;
                    float4x4 _19940;
                    do
                    {
                        float4x4 _10266;
                        bool _19939;
                        do
                        {
                            _10266 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19939 = false;
                                break;
                            }
                            uint _10300 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10300 + 32u) * 4 + 0) != 1u)
                            {
                                _19939 = false;
                                break;
                            }
                            uint _19936;
                            _19936 = 0u;
                            for (; _19936 < 4u; _19936++)
                            {
                                for (uint _19937 = 0u; _19937 < 4u; )
                                {
                                    _10266[_19936][_19937] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10300 + (_19936 * 4u)) + _19937) * 4 + 0));
                                    _19937++;
                                    continue;
                                }
                            }
                            _19939 = true;
                            break;
                        } while(false);
                        if (_19939)
                        {
                            _19940 = _10266;
                            break;
                        }
                        _19940 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19941;
                    do
                    {
                        float _10380 = 1.0f - _19888.y;
                        float4 _10391 = mul(float4((float2(_19888.x, _10380) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19888 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10252_dummy_parameter))))), 0)).x, 1.0f), _19940);
                        float _10393 = _10391.w;
                        if (!(_10393 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19941 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10406 = ((_10391.xy / _10393.xx) + 1.0f.xx) * 0.5f;
                        _19941 = float2(_10406.x - _19888.x, _10380 - _10406.y);
                        break;
                    } while(false);
                    float2 _10203 = abs(_19941);
                    if (any(bool2(_10203.x > 100000.0f.xx.x, _10203.y > 100000.0f.xx.y)))
                    {
                        _19942 = false;
                        break;
                    }
                    float _10211 = length(_19941 * _5802);
                    uint _10426_dummy_parameter;
                    bool _10225 = _10211 > ((8.0f * _5802.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10232;
                    if (_10225)
                    {
                        _10232 = length((r_motion_tp1.Load(int3(int2(floor(_19888 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10426_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5802) < (0.20000000298023223876953125f * _10211);
                    }
                    else
                    {
                        _10232 = _10225;
                    }
                    _19942 = _10232;
                    break;
                } while(false);
                bool _19949;
                do
                {
                    bool _10512 = all(bool2(_19889.x > 0.0f.xx.x, _19889.y > 0.0f.xx.y));
                    bool _10518;
                    if (_10512)
                    {
                        _10518 = all(bool2(_19889.x < 1.0f.xx.x, _19889.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10518 = _10512;
                    }
                    if (!_10518)
                    {
                        _19949 = false;
                        break;
                    }
                    uint _10525_dummy_parameter;
                    float4x4 _19947;
                    do
                    {
                        float4x4 _10539;
                        bool _19946;
                        do
                        {
                            _10539 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19946 = false;
                                break;
                            }
                            uint _10573 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10573 + 32u) * 4 + 0) != 1u)
                            {
                                _19946 = false;
                                break;
                            }
                            uint _19943;
                            _19943 = 0u;
                            for (; _19943 < 4u; _19943++)
                            {
                                for (uint _19944 = 0u; _19944 < 4u; )
                                {
                                    _10539[_19943][_19944] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10573 + (_19943 * 4u)) + _19944) * 4 + 0));
                                    _19944++;
                                    continue;
                                }
                            }
                            _19946 = true;
                            break;
                        } while(false);
                        if (_19946)
                        {
                            _19947 = _10539;
                            break;
                        }
                        _19947 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19948;
                    do
                    {
                        float _10653 = 1.0f - _19889.y;
                        float4 _10664 = mul(float4((float2(_19889.x, _10653) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19889 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10525_dummy_parameter))))), 0)).x, 1.0f), _19947);
                        float _10666 = _10664.w;
                        if (!(_10666 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19948 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10679 = ((_10664.xy / _10666.xx) + 1.0f.xx) * 0.5f;
                        _19948 = float2(_10679.x - _19889.x, _10653 - _10679.y);
                        break;
                    } while(false);
                    float2 _10476 = abs(_19948);
                    if (any(bool2(_10476.x > 100000.0f.xx.x, _10476.y > 100000.0f.xx.y)))
                    {
                        _19949 = false;
                        break;
                    }
                    float _10484 = length(_19948 * _5802);
                    uint _10699_dummy_parameter;
                    bool _10498 = _10484 > ((8.0f * _5802.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10505;
                    if (_10498)
                    {
                        _10505 = length((r_motion_tp1.Load(int3(int2(floor(_19889 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10699_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5802) < (0.20000000298023223876953125f * _10484);
                    }
                    else
                    {
                        _10505 = _10498;
                    }
                    _19949 = _10505;
                    break;
                } while(false);
                bool _19956;
                do
                {
                    bool _10785 = all(bool2(_19890.x > 0.0f.xx.x, _19890.y > 0.0f.xx.y));
                    bool _10791;
                    if (_10785)
                    {
                        _10791 = all(bool2(_19890.x < 1.0f.xx.x, _19890.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10791 = _10785;
                    }
                    if (!_10791)
                    {
                        _19956 = false;
                        break;
                    }
                    uint _10798_dummy_parameter;
                    float4x4 _19954;
                    do
                    {
                        float4x4 _10812;
                        bool _19953;
                        do
                        {
                            _10812 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19953 = false;
                                break;
                            }
                            uint _10846 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10846 + 32u) * 4 + 0) != 1u)
                            {
                                _19953 = false;
                                break;
                            }
                            uint _19950;
                            _19950 = 0u;
                            for (; _19950 < 4u; _19950++)
                            {
                                for (uint _19951 = 0u; _19951 < 4u; )
                                {
                                    _10812[_19950][_19951] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10846 + (_19950 * 4u)) + _19951) * 4 + 0));
                                    _19951++;
                                    continue;
                                }
                            }
                            _19953 = true;
                            break;
                        } while(false);
                        if (_19953)
                        {
                            _19954 = _10812;
                            break;
                        }
                        _19954 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19955;
                    do
                    {
                        float _10926 = 1.0f - _19890.y;
                        float4 _10937 = mul(float4((float2(_19890.x, _10926) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19890 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10798_dummy_parameter))))), 0)).x, 1.0f), _19954);
                        float _10939 = _10937.w;
                        if (!(_10939 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19955 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10952 = ((_10937.xy / _10939.xx) + 1.0f.xx) * 0.5f;
                        _19955 = float2(_10952.x - _19890.x, _10926 - _10952.y);
                        break;
                    } while(false);
                    float2 _10749 = abs(_19955);
                    if (any(bool2(_10749.x > 100000.0f.xx.x, _10749.y > 100000.0f.xx.y)))
                    {
                        _19956 = false;
                        break;
                    }
                    float _10757 = length(_19955 * _5802);
                    uint _10972_dummy_parameter;
                    bool _10771 = _10757 > ((8.0f * _5802.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10778;
                    if (_10771)
                    {
                        _10778 = length((r_motion_tp1.Load(int3(int2(floor(_19890 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10972_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5802) < (0.20000000298023223876953125f * _10757);
                    }
                    else
                    {
                        _10778 = _10771;
                    }
                    _19956 = _10778;
                    break;
                } while(false);
                float4 _5870 = _8794 * float4(_19935 ? 0.0f : 1.0f, _19942 ? 0.0f : 1.0f, _19949 ? 0.0f : 1.0f, _19956 ? 0.0f : 1.0f);
                float _5872 = dot(_5870, 1.0f.xxxx);
                float4 _20099;
                if (_5872 > 0.001000000047497451305389404296875f)
                {
                    _20099 = _5870 / _5872.xxxx;
                }
                else
                {
                    _20099 = _8794;
                }
                _20098 = _20099;
            }
            else
            {
                _20098 = _8794;
            }
            _21405 = _5843;
            _20097 = _20098;
        }
        else
        {
            _21405 = 0.0f;
            _20097 = _8794;
        }
        bool _5889 = _5581 && (!_20026);
        bool _5898;
        if (_5889)
        {
            _5898 = (_20097.z + _20097.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5898 = _5889;
        }
        bool _5909;
        if (_5898)
        {
            _5909 = length((_19889 - _19886) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5909 = _5898;
        }
        bool _20186;
        if (_5909)
        {
            uint4 _11001 = r_warped_motion_qdata_tp1.Load(int3(_20107, 0));
            uint _11002 = _11001.x;
            bool _20189;
            if (_11002 != 0u)
            {
                float _20175;
                if (_11002 == 0u)
                {
                    _20175 = -1.0f;
                }
                else
                {
                    _20175 = float((_11002 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5919 = _20175 - 0.12000000476837158203125f;
                bool _11021 = all(bool2(_19889.x > 0.0f.xx.x, _19889.y > 0.0f.xx.y));
                bool _11027;
                if (_11021)
                {
                    _11027 = all(bool2(_19889.x < 1.0f.xx.x, _19889.y < 1.0f.xx.y));
                }
                else
                {
                    _11027 = _11021;
                }
                bool _5929;
                if (_11027)
                {
                    uint _11034_dummy_parameter;
                    _5929 = (log((r_depth_tm1.Load(int3(int2(floor(_19889 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11034_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5919;
                }
                else
                {
                    _5929 = _11027;
                }
                bool _5943;
                if (!_5929)
                {
                    bool _11064 = all(bool2(_19890.x > 0.0f.xx.x, _19890.y > 0.0f.xx.y));
                    bool _11070;
                    if (_11064)
                    {
                        _11070 = all(bool2(_19890.x < 1.0f.xx.x, _19890.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11070 = _11064;
                    }
                    bool _5941;
                    if (_11070)
                    {
                        uint _11077_dummy_parameter;
                        _5941 = (log((r_depth_tp1.Load(int3(int2(floor(_19890 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11077_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5919;
                    }
                    else
                    {
                        _5941 = _11070;
                    }
                    _5943 = _5941;
                }
                else
                {
                    _5943 = _5929;
                }
                _20189 = _5943;
            }
            else
            {
                _20189 = false;
            }
            _20186 = _20189;
        }
        else
        {
            _20186 = false;
        }
        bool _5948 = _20026 || _20186;
        bool _5953;
        if (_5948)
        {
            bool _11107 = all(bool2(_19886.x > 0.0f.xx.x, _19886.y > 0.0f.xx.y));
            bool _11113;
            if (_11107)
            {
                _11113 = all(bool2(_19886.x < 1.0f.xx.x, _19886.y < 1.0f.xx.y));
            }
            else
            {
                _11113 = _11107;
            }
            _5953 = _11113;
        }
        else
        {
            _5953 = _5948;
        }
        bool _5958;
        if (_5953)
        {
            bool _11118 = all(bool2(_19888.x > 0.0f.xx.x, _19888.y > 0.0f.xx.y));
            bool _11124;
            if (_11118)
            {
                _11124 = all(bool2(_19888.x < 1.0f.xx.x, _19888.y < 1.0f.xx.y));
            }
            else
            {
                _11124 = _11118;
            }
            _5958 = _11124;
        }
        else
        {
            _5958 = _5953;
        }
        float4 _20309;
        if (_5958)
        {
            float _5964 = _20097.x + _20097.y;
            float _5969 = _20097.z + _20097.w;
            float _20204;
            if (_5964 > 0.001000000047497451305389404296875f)
            {
                _20204 = _20097.x / _5964;
            }
            else
            {
                _20204 = _5769;
            }
            _20309 = float4(_20097.x + (_5969 * _20204), _20097.y + (_5969 * (1.0f - _20204)), 0.0f, 0.0f);
        }
        else
        {
            _20309 = _20097;
        }
        bool _11152 = (cbFI_pad0 & 1024u) != 0u;
        bool _11128 = !_11152;
        bool _11129 = !_11128;
        bool _11146;
        if (_11129)
        {
            _11146 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_20107.y * cbFI_MvDepthLaneSize.x) + _20107.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11146 = _11128;
        }
        bool _11178;
        if (_11129)
        {
            _11178 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5560.y * cbFI_FlowLaneSize.x) + _5560.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11178 = _11128;
        }
        float _6004 = float(_11178);
        bool _20330;
        float4 _20369;
        float3 _22316;
        if (_11152)
        {
            bool _6014;
            if (_11146)
            {
                _6014 = all(bool2(_19886.x > 0.0f.xx.x, _19886.y > 0.0f.xx.y));
            }
            else
            {
                _6014 = _11146;
            }
            bool _6020;
            if (_6014)
            {
                _6020 = all(bool2(_19886.x < 1.0f.xx.x, _19886.y < 1.0f.xx.y));
            }
            else
            {
                _6020 = _6014;
            }
            bool _6027;
            if (_11146)
            {
                _6027 = all(bool2(_19888.x > 0.0f.xx.x, _19888.y > 0.0f.xx.y));
            }
            else
            {
                _6027 = _11146;
            }
            bool _6033;
            if (_6027)
            {
                _6033 = all(bool2(_19888.x < 1.0f.xx.x, _19888.y < 1.0f.xx.y));
            }
            else
            {
                _6033 = _6027;
            }
            bool _6040;
            if (_11178)
            {
                _6040 = all(bool2(_19889.x > 0.0f.xx.x, _19889.y > 0.0f.xx.y));
            }
            else
            {
                _6040 = _11178;
            }
            bool _6046;
            if (_6040)
            {
                _6046 = all(bool2(_19889.x < 1.0f.xx.x, _19889.y < 1.0f.xx.y));
            }
            else
            {
                _6046 = _6040;
            }
            bool _6053;
            if (_11178)
            {
                _6053 = all(bool2(_19890.x > 0.0f.xx.x, _19890.y > 0.0f.xx.y));
            }
            else
            {
                _6053 = _11178;
            }
            bool _6059;
            if (_6053)
            {
                _6059 = all(bool2(_19890.x < 1.0f.xx.x, _19890.y < 1.0f.xx.y));
            }
            else
            {
                _6059 = _6053;
            }
            bool _6061 = !_11146;
            if (_6061)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11220;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11220);
                }
            }
            bool _6066 = !_11178;
            if (_6066)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11230;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11230);
                }
            }
            if (_11146 && _6066)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11240;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11240);
                }
            }
            if (_6061 && _11178)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11250;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11250);
                }
            }
            float _6085 = float(_6020);
            float _6087 = float(_6033);
            bool _6090 = _6046 && _6059;
            float _20238;
            if (_6090)
            {
                _20238 = 1.0f;
            }
            else
            {
                _20238 = (_6046 || _6059) ? 0.5f : 0.0f;
            }
            bool _20253;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_6020)) && (!_6033))
            {
                bool _6120;
                if (_6090)
                {
                    float _20246;
                    do
                    {
                        bool _11334 = all(bool2(_19889.x > 0.0f.xx.x, _19889.y > 0.0f.xx.y));
                        bool _11340;
                        if (_11334)
                        {
                            _11340 = all(bool2(_19889.x < 1.0f.xx.x, _19889.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11340 = _11334;
                        }
                        bool _11271 = !_11340;
                        bool _11278;
                        if (!_11271)
                        {
                            bool _11345 = all(bool2(_19890.x > 0.0f.xx.x, _19890.y > 0.0f.xx.y));
                            bool _11351;
                            if (_11345)
                            {
                                _11351 = all(bool2(_19890.x < 1.0f.xx.x, _19890.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11351 = _11345;
                            }
                            _11278 = !_11351;
                        }
                        else
                        {
                            _11278 = _11271;
                        }
                        if (_11278)
                        {
                            _20246 = 0.0f;
                            break;
                        }
                        uint _11358_dummy_parameter;
                        uint _11374_dummy_parameter;
                        float4x4 _20245;
                        do
                        {
                            float4x4 _11388;
                            bool _20244;
                            do
                            {
                                _11388 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20244 = false;
                                    break;
                                }
                                uint _11422 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11422 + 32u) * 4 + 0) != 1u)
                                {
                                    _20244 = false;
                                    break;
                                }
                                uint _20241;
                                _20241 = 0u;
                                for (; _20241 < 4u; _20241++)
                                {
                                    for (uint _20242 = 0u; _20242 < 4u; )
                                    {
                                        _11388[_20241][_20242] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11422 + 16u) + (_20241 * 4u)) + _20242) * 4 + 0));
                                        _20242++;
                                        continue;
                                    }
                                }
                                _20244 = true;
                                break;
                            } while(false);
                            if (_20244)
                            {
                                _20245 = _11388;
                                break;
                            }
                            _20245 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11299 = mul(float4((float2(_19889.x, 1.0f - _19889.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19889 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11358_dummy_parameter))))), 0)).x, 1.0f), _20245);
                        float _11301 = _11299.w;
                        if (abs(_11301) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20246 = 0.0f;
                            break;
                        }
                        float _11312 = abs(cbFI_DeviceToViewDepth.y / ((_11299.z / _11301) - cbFI_DeviceToViewDepth.x));
                        float _11315 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19890 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11374_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20246 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11312 - _11315) / max(max(_11312, _11315), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _6120 = _20246 >= 0.5f;
                }
                else
                {
                    _6120 = _6090;
                }
                bool _6128;
                if (_6120)
                {
                    _6128 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _6128 = _6120;
                }
                bool _20254;
                if (_6128)
                {
                    uint _11526_dummy_parameter;
                    float4x4 _20251;
                    do
                    {
                        float4x4 _11540;
                        bool _20250;
                        do
                        {
                            _11540 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20250 = false;
                                break;
                            }
                            uint _11574 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11574 + 32u) * 4 + 0) != 1u)
                            {
                                _20250 = false;
                                break;
                            }
                            uint _20247;
                            _20247 = 0u;
                            for (; _20247 < 4u; _20247++)
                            {
                                for (uint _20248 = 0u; _20248 < 4u; )
                                {
                                    _11540[_20247][_20248] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11574 + 16u) + (_20247 * 4u)) + _20248) * 4 + 0));
                                    _20248++;
                                    continue;
                                }
                            }
                            _20250 = true;
                            break;
                        } while(false);
                        if (_20250)
                        {
                            _20251 = _11540;
                            break;
                        }
                        _20251 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20252;
                    do
                    {
                        float _11654 = 1.0f - _19889.y;
                        float4 _11665 = mul(float4((float2(_19889.x, _11654) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19889 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11526_dummy_parameter))))), 0)).x, 1.0f), _20251);
                        float _11667 = _11665.w;
                        if (!(_11667 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20252 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11680 = ((_11665.xy / _11667.xx) + 1.0f.xx) * 0.5f;
                        _20252 = float2(_11680.x - _19889.x, _11654 - _11680.y);
                        break;
                    } while(false);
                    float2 _6141 = float2(cbFI_DisplaySize);
                    _20254 = length(((_19889 + _20252) - _19890) * _6141) <= ((0.100000001490116119384765625f * length(_20252 * _6141)) + 8.0f);
                }
                else
                {
                    _20254 = _6120;
                }
                _20253 = _20254;
            }
            else
            {
                _20253 = true;
            }
            bool _6155 = !_20253;
            bool _23758 = _6155 ? false : _6059;
            bool _23759 = _6155 ? false : _6046;
            bool _20331;
            float4 _20370;
            if (!(((_6020 && _6033) && _23759) && _23758))
            {
                float4 _6177 = _20309 * float4(_6085, _6087, float(_23759), float(_23758));
                float _6179 = dot(_6177, 1.0f.xxxx);
                bool _6182 = !(_6179 > 0.0f);
                float4 _20371;
                if (!_6182)
                {
                    _20371 = _6177 / _6179.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11702;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11702);
                    }
                    _20371 = 0.0f.xxxx;
                }
                _20370 = _20371;
                _20331 = _6182;
            }
            else
            {
                _20370 = _20309;
                _20331 = false;
            }
            _22316 = float3(_6085, _6087, _20238);
            _20369 = _20370;
            _20330 = _20331;
        }
        else
        {
            _22316 = float3(float(_11146), _6004, 0.0f);
            _20369 = _20309;
            _20330 = false;
        }
        bool _6200 = !_20330;
        float4 _20462;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6200)
        {
            float _6207 = _20369.x + _20369.y;
            float4 _20463;
            if (_6207 > 0.001000000047497451305389404296875f)
            {
                _20463 = float4(_20369.x / _6207, _20369.y / _6207, 0.0f, 0.0f);
            }
            else
            {
                _20463 = float4(_5769, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20462 = _20463;
        }
        else
        {
            _20462 = _20369;
        }
        float4 _20639;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6200) && _11146)
        {
            float _20436;
            do
            {
                uint4 _11842 = r_warped_motion_qdata_tp1.Load(int3(_20107, 0));
                uint _11843 = _11842.x;
                if (_11843 != 0u)
                {
                    float _20435;
                    if (_11843 == 0u)
                    {
                        _20435 = -1.0f;
                    }
                    else
                    {
                        _20435 = float((_11843 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20436 = _20435;
                    break;
                }
                int _20418;
                uint _20419;
                _20419 = _11843;
                _20418 = -1;
                uint _20434;
                for (; _20418 <= 1; _20419 = _20434, _20418++)
                {
                    _20434 = _20419;
                    for (int _20432 = -1; _20432 <= 1; )
                    {
                        _20434 = max(_20434, r_warped_motion_qdata_tp1.Load(int3(clamp(_20107 + int2(_20432, _20418), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20432++;
                        continue;
                    }
                }
                if (_20419 != 0u)
                {
                    float _20431;
                    if (_20419 == 0u)
                    {
                        _20431 = -1.0f;
                    }
                    else
                    {
                        _20431 = float((_20419 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20436 = _20431;
                    break;
                }
                uint _20421;
                _20421 = 4294967295u;
                uint _23651;
                for (int _20420 = 0; _20420 < 8; _20421 = _23651, _20420++)
                {
                    int _20424 = 0;
                    for (;;)
                    {
                        if (_20424 < 5)
                        {
                            int2 _11793 = _20107 + (_1243[_20420] * _1252[_20424].xx);
                            bool _11796 = any(bool2(_11793.x < int2(0, 0).x, _11793.y < int2(0, 0).y));
                            bool _11804;
                            if (!_11796)
                            {
                                _11804 = any(bool2(_11793.x >= cbFI_MvDepthLaneSize.x, _11793.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11804 = _11796;
                            }
                            if (_11804)
                            {
                                _23651 = _20421;
                                break;
                            }
                            uint4 _11882 = r_warped_motion_qdata_tp1.Load(int3(_11793, 0));
                            uint _11883 = _11882.x;
                            if (_11883 != 0u)
                            {
                                _23651 = min(_20421, _11883);
                                break;
                            }
                            _20424++;
                            continue;
                        }
                        else
                        {
                            _23651 = _20421;
                            break;
                        }
                    }
                }
                float _20423;
                if (_20421 == 4294967295u)
                {
                    _20423 = -1.0f;
                }
                else
                {
                    float _20422;
                    if (_20421 == 0u)
                    {
                        _20422 = -1.0f;
                    }
                    else
                    {
                        _20422 = float((_20421 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20423 = _20422;
                }
                _20436 = _20423;
                break;
            } while(false);
            float _6243 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6246 = r_warped_motion_qdata_tp1.Load(int3(_20107, 0)).x == 0u;
            bool _6252;
            if (_6246)
            {
                bool _11908 = all(bool2(_19886.x > 0.0f.xx.x, _19886.y > 0.0f.xx.y));
                bool _11914;
                if (_11908)
                {
                    _11914 = all(bool2(_19886.x < 1.0f.xx.x, _19886.y < 1.0f.xx.y));
                }
                else
                {
                    _11914 = _11908;
                }
                _6252 = _11914;
            }
            else
            {
                _6252 = _6246;
            }
            bool _6257;
            if (_6252)
            {
                bool _11919 = all(bool2(_19888.x > 0.0f.xx.x, _19888.y > 0.0f.xx.y));
                bool _11925;
                if (_11919)
                {
                    _11925 = all(bool2(_19888.x < 1.0f.xx.x, _19888.y < 1.0f.xx.y));
                }
                else
                {
                    _11925 = _11919;
                }
                _6257 = _11925;
            }
            else
            {
                _6257 = _6252;
            }
            bool _20448;
            float4 _20457;
            if (_6257)
            {
                uint _11932_dummy_parameter;
                float _11956 = log((r_depth_tm1.Load(int3(int2(floor(_19886 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11932_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _11964_dummy_parameter;
                float _11988 = log((r_depth_tp1.Load(int3(int2(floor(_19888 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11964_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _6268 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6275;
                if (_6268)
                {
                    _6275 = _11988 > (_11956 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6275 = _6268;
                }
                bool _20453;
                float4 _20475;
                if (_6275)
                {
                    _20475 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20453 = true;
                }
                else
                {
                    bool _6281 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6288;
                    if (_6281)
                    {
                        _6288 = _11956 > (_11988 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6288 = _6281;
                    }
                    bool4 _23760 = _6288.xxxx;
                    _20475 = float4(_23760.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20462.x, _23760.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20462.y, _23760.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20462.z, _23760.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20462.w);
                    _20453 = _6288 ? true : false;
                }
                _20457 = _20475;
                _20448 = _20453;
            }
            else
            {
                _20457 = _20462;
                _20448 = false;
            }
            float4 _20530;
            if (_20448)
            {
                _20530 = 1.0f.xxxx;
            }
            else
            {
                bool _6299 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6305;
                if (_6299)
                {
                    _6305 = _20457.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6305 = _6299;
                }
                bool _6310;
                if (_6305)
                {
                    bool _11994 = all(bool2(_19888.x > 0.0f.xx.x, _19888.y > 0.0f.xx.y));
                    bool _12000;
                    if (_11994)
                    {
                        _12000 = all(bool2(_19888.x < 1.0f.xx.x, _19888.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12000 = _11994;
                    }
                    _6310 = _12000;
                }
                else
                {
                    _6310 = _6305;
                }
                float4 _20531;
                if (_6310)
                {
                    float _20484;
                    if (_20436 >= 0.0f)
                    {
                        _20484 = _20436 - _6243;
                    }
                    else
                    {
                        float _20480;
                        _20480 = 2.0f;
                        float _12057;
                        for (int _20479 = 0; _20479 < 24; _20480 = _12057, _20479++)
                        {
                            float _12021 = float(_20479 & 7) * 0.785398185253143310546875f;
                            int _12023 = _20479 >> 3;
                            int _20481;
                            if (_12023 == 0)
                            {
                                _20481 = 16;
                            }
                            else
                            {
                                _20481 = (_12023 == 1) ? 48 : 96;
                            }
                            uint _12089_dummy_parameter;
                            _12057 = min(_20480, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19888 + ((cbFI_MvDepthLaneSizeRcp * float(_20481)) * float2(cos(_12021), sin(_12021))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12089_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20484 = _20480;
                    }
                    uint _12121_dummy_parameter;
                    float4 _20532;
                    if (r_depth_tp1.Load(int3(int2(floor(_19888 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12121_dummy_parameter))))), 0)).x > ((exp((_20484 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20532 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20532 = 1.0f.xxxx;
                    }
                    _20531 = _20532;
                }
                else
                {
                    _20531 = 1.0f.xxxx;
                }
                _20530 = _20531;
            }
            bool _6338 = _20436 >= 0.0f;
            bool _6339 = (!_20448) && _6338;
            bool _6346;
            if (_6339)
            {
                _6346 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6346 = _6339;
            }
            bool _6352;
            if (_6346)
            {
                _6352 = _20457.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6352 = _6346;
            }
            bool _6357;
            if (_6352)
            {
                bool _12145 = all(bool2(_19886.x > 0.0f.xx.x, _19886.y > 0.0f.xx.y));
                bool _12151;
                if (_12145)
                {
                    _12151 = all(bool2(_19886.x < 1.0f.xx.x, _19886.y < 1.0f.xx.y));
                }
                else
                {
                    _12151 = _12145;
                }
                _6357 = _12151;
            }
            else
            {
                _6357 = _6352;
            }
            float4 _20555;
            if (_6357)
            {
                float _20524;
                if (_6338)
                {
                    _20524 = _20436 - _6243;
                }
                else
                {
                    float _20520;
                    _20520 = 2.0f;
                    float _12208;
                    for (int _20519 = 0; _20519 < 24; _20520 = _12208, _20519++)
                    {
                        float _12172 = float(_20519 & 7) * 0.785398185253143310546875f;
                        int _12174 = _20519 >> 3;
                        int _20521;
                        if (_12174 == 0)
                        {
                            _20521 = 16;
                        }
                        else
                        {
                            _20521 = (_12174 == 1) ? 48 : 96;
                        }
                        uint _12224_dummy_parameter;
                        _12208 = min(_20520, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19886 + ((cbFI_MvDepthLaneSizeRcp * float(_20521)) * float2(cos(_12172), sin(_12172))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12224_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20524 = _20520;
                }
                uint _12272_dummy_parameter;
                float4 _20556;
                if (r_depth_tm1.Load(int3(int2(floor(_19886 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12272_dummy_parameter))))), 0)).x > ((exp((_20524 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19552 = _20530;
                    _19552.x = 0.0f;
                    _20556 = _19552;
                }
                else
                {
                    _20556 = _20530;
                }
                _20555 = _20556;
            }
            else
            {
                _20555 = _20530;
            }
            float4 _20568;
            if (_6339)
            {
                float _12298 = (exp(((_20436 - _6243) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6395 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6401;
                if (_6395)
                {
                    _6401 = _20457.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6401 = _6395;
                }
                bool _6406;
                if (_6401)
                {
                    bool _12303 = all(bool2(_19890.x > 0.0f.xx.x, _19890.y > 0.0f.xx.y));
                    bool _12309;
                    if (_12303)
                    {
                        _12309 = all(bool2(_19890.x < 1.0f.xx.x, _19890.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12309 = _12303;
                    }
                    _6406 = _12309;
                }
                else
                {
                    _6406 = _6401;
                }
                bool _6414;
                if (_6406)
                {
                    uint _12316_dummy_parameter;
                    _6414 = r_depth_tp1.Load(int3(int2(floor(_19890 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12316_dummy_parameter))))), 0)).x > _12298;
                }
                else
                {
                    _6414 = _6406;
                }
                float4 _20566;
                if (_6414)
                {
                    float4 _19555 = _20555;
                    _19555.w = 0.0f;
                    _20566 = _19555;
                }
                else
                {
                    _20566 = _20555;
                }
                bool _6421 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6427;
                if (_6421)
                {
                    _6427 = _20457.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6427 = _6421;
                }
                bool _6432;
                if (_6427)
                {
                    bool _12333 = all(bool2(_19889.x > 0.0f.xx.x, _19889.y > 0.0f.xx.y));
                    bool _12339;
                    if (_12333)
                    {
                        _12339 = all(bool2(_19889.x < 1.0f.xx.x, _19889.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12339 = _12333;
                    }
                    _6432 = _12339;
                }
                else
                {
                    _6432 = _6427;
                }
                bool _6440;
                if (_6432)
                {
                    uint _12346_dummy_parameter;
                    _6440 = r_depth_tm1.Load(int3(int2(floor(_19889 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12346_dummy_parameter))))), 0)).x > _12298;
                }
                else
                {
                    _6440 = _6432;
                }
                float4 _20569;
                if (_6440)
                {
                    float4 _19558 = _20566;
                    _19558.z = 0.0f;
                    _20569 = _19558;
                }
                else
                {
                    _20569 = _20566;
                }
                _20568 = _20569;
            }
            else
            {
                _20568 = _20555;
            }
            float4 _20640;
            if (any(bool4(_20568.x < 1.0f.xxxx.x, _20568.y < 1.0f.xxxx.y, _20568.z < 1.0f.xxxx.z, _20568.w < 1.0f.xxxx.w)))
            {
                float4 _6451 = _20457 * _20568;
                float _6453 = dot(_6451, 1.0f.xxxx);
                float4 _20641;
                if (_6453 > 0.0f)
                {
                    _20641 = _6451 / _6453.xxxx;
                }
                else
                {
                    bool _6464 = _20568.y == 0.0f;
                    bool _6470;
                    if (_6464)
                    {
                        _6470 = _20568.x > 0.0f;
                    }
                    else
                    {
                        _6470 = _6464;
                    }
                    bool _6475;
                    if (_6470)
                    {
                        bool _12363 = all(bool2(_19886.x > 0.0f.xx.x, _19886.y > 0.0f.xx.y));
                        bool _12369;
                        if (_12363)
                        {
                            _12369 = all(bool2(_19886.x < 1.0f.xx.x, _19886.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12369 = _12363;
                        }
                        _6475 = _12369;
                    }
                    else
                    {
                        _6475 = _6470;
                    }
                    float4 _20642;
                    if (_6475)
                    {
                        _20642 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6480 = _20568.x == 0.0f;
                        bool _6486;
                        if (_6480)
                        {
                            _6486 = _20568.y > 0.0f;
                        }
                        else
                        {
                            _6486 = _6480;
                        }
                        bool _6491;
                        if (_6486)
                        {
                            bool _12374 = all(bool2(_19888.x > 0.0f.xx.x, _19888.y > 0.0f.xx.y));
                            bool _12380;
                            if (_12374)
                            {
                                _12380 = all(bool2(_19888.x < 1.0f.xx.x, _19888.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12380 = _12374;
                            }
                            _6491 = _12380;
                        }
                        else
                        {
                            _6491 = _6486;
                        }
                        bool4 _23763 = _6491.xxxx;
                        _20642 = float4(_23763.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20457.x, _23763.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20457.y, _23763.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20457.z, _23763.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20457.w);
                    }
                    _20641 = _20642;
                }
                _20640 = _20641;
            }
            else
            {
                _20640 = _20457;
            }
            _20639 = _20640;
        }
        else
        {
            _20639 = _20462;
        }
        float4 _21369;
        bool _21675;
        float3 _22012;
        if (((cbFI_pad0 & 32768u) != 0u) && _6200)
        {
            bool _6508 = _20639.x > 0.00999999977648258209228515625f;
            bool _6511 = _20639.y > 0.00999999977648258209228515625f;
            bool _6520 = (_20639.z + _20639.w) > 0.0199999995529651641845703125f;
            bool _6526;
            if (_6520)
            {
                bool _12385 = all(bool2(_19889.x > 0.0f.xx.x, _19889.y > 0.0f.xx.y));
                bool _12391;
                if (_12385)
                {
                    _12391 = all(bool2(_19889.x < 1.0f.xx.x, _19889.y < 1.0f.xx.y));
                }
                else
                {
                    _12391 = _12385;
                }
                _6526 = _12391;
            }
            else
            {
                _6526 = _6520;
            }
            bool _6531;
            if (_6526)
            {
                bool _12396 = all(bool2(_19890.x > 0.0f.xx.x, _19890.y > 0.0f.xx.y));
                bool _12402;
                if (_12396)
                {
                    _12402 = all(bool2(_19890.x < 1.0f.xx.x, _19890.y < 1.0f.xx.y));
                }
                else
                {
                    _12402 = _12396;
                }
                _6531 = _12402;
            }
            else
            {
                _6531 = _6526;
            }
            bool _6538;
            if (_6531)
            {
                float _20655;
                do
                {
                    bool _12485 = all(bool2(_19889.x > 0.0f.xx.x, _19889.y > 0.0f.xx.y));
                    bool _12491;
                    if (_12485)
                    {
                        _12491 = all(bool2(_19889.x < 1.0f.xx.x, _19889.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12491 = _12485;
                    }
                    bool _12422 = !_12491;
                    bool _12429;
                    if (!_12422)
                    {
                        bool _12496 = all(bool2(_19890.x > 0.0f.xx.x, _19890.y > 0.0f.xx.y));
                        bool _12502;
                        if (_12496)
                        {
                            _12502 = all(bool2(_19890.x < 1.0f.xx.x, _19890.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12502 = _12496;
                        }
                        _12429 = !_12502;
                    }
                    else
                    {
                        _12429 = _12422;
                    }
                    if (_12429)
                    {
                        _20655 = 0.0f;
                        break;
                    }
                    uint _12509_dummy_parameter;
                    uint _12525_dummy_parameter;
                    float4x4 _20654;
                    do
                    {
                        float4x4 _12539;
                        bool _20653;
                        do
                        {
                            _12539 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20653 = false;
                                break;
                            }
                            uint _12573 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12573 + 32u) * 4 + 0) != 1u)
                            {
                                _20653 = false;
                                break;
                            }
                            uint _20650;
                            _20650 = 0u;
                            for (; _20650 < 4u; _20650++)
                            {
                                for (uint _20651 = 0u; _20651 < 4u; )
                                {
                                    _12539[_20650][_20651] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12573 + 16u) + (_20650 * 4u)) + _20651) * 4 + 0));
                                    _20651++;
                                    continue;
                                }
                            }
                            _20653 = true;
                            break;
                        } while(false);
                        if (_20653)
                        {
                            _20654 = _12539;
                            break;
                        }
                        _20654 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12450 = mul(float4((float2(_19889.x, 1.0f - _19889.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19889 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12509_dummy_parameter))))), 0)).x, 1.0f), _20654);
                    float _12452 = _12450.w;
                    if (abs(_12452) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20655 = 0.0f;
                        break;
                    }
                    float _12463 = abs(cbFI_DeviceToViewDepth.y / ((_12450.z / _12452) - cbFI_DeviceToViewDepth.x));
                    float _12466 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19890 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12525_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20655 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12463 - _12466) / max(max(_12463, _12466), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6538 = _20655 < 0.5f;
            }
            else
            {
                _6538 = _6531;
            }
            float4 _20674;
            if (_6538)
            {
                uint _12677_dummy_parameter;
                uint _12708_dummy_parameter;
                float4 _20675;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19889 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12677_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19890 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12708_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20675 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20675 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20674 = _20675;
            }
            else
            {
                _20674 = 1.0f.xxxx;
            }
            bool _6562;
            if (_11146)
            {
                bool _12737 = all(bool2(_19886.x > 0.0f.xx.x, _19886.y > 0.0f.xx.y));
                bool _12743;
                if (_12737)
                {
                    _12743 = all(bool2(_19886.x < 1.0f.xx.x, _19886.y < 1.0f.xx.y));
                }
                else
                {
                    _12743 = _12737;
                }
                _6562 = _12743;
            }
            else
            {
                _6562 = _11146;
            }
            bool _6568;
            if (_11146)
            {
                bool _12748 = all(bool2(_19888.x > 0.0f.xx.x, _19888.y > 0.0f.xx.y));
                bool _12754;
                if (_12748)
                {
                    _12754 = all(bool2(_19888.x < 1.0f.xx.x, _19888.y < 1.0f.xx.y));
                }
                else
                {
                    _12754 = _12748;
                }
                _6568 = _12754;
            }
            else
            {
                _6568 = _11146;
            }
            bool _6574;
            if (_11178)
            {
                bool _12759 = all(bool2(_19889.x > 0.0f.xx.x, _19889.y > 0.0f.xx.y));
                bool _12765;
                if (_12759)
                {
                    _12765 = all(bool2(_19889.x < 1.0f.xx.x, _19889.y < 1.0f.xx.y));
                }
                else
                {
                    _12765 = _12759;
                }
                _6574 = _12765;
            }
            else
            {
                _6574 = _11178;
            }
            bool _6580;
            if (_11178)
            {
                bool _12770 = all(bool2(_19890.x > 0.0f.xx.x, _19890.y > 0.0f.xx.y));
                bool _12776;
                if (_12770)
                {
                    _12776 = all(bool2(_19890.x < 1.0f.xx.x, _19890.y < 1.0f.xx.y));
                }
                else
                {
                    _12776 = _12770;
                }
                _6580 = _12776;
            }
            else
            {
                _6580 = _11178;
            }
            bool _6583 = _6574 != _6580;
            bool _6589;
            if (_6583)
            {
                _6589 = _6562 || _6568;
            }
            else
            {
                _6589 = _6583;
            }
            float4 _20777;
            if (_6589)
            {
                float4 _19585 = _20674;
                _19585.z = 0.0f;
                _19585.w = 0.0f;
                _20777 = _19585;
            }
            else
            {
                _20777 = _20674;
            }
            bool _6596 = _6562 && _6508;
            bool _6599 = _6568 && _6511;
            float4 _20882;
            float3 _22121;
            if (_6596 || _6599)
            {
                float _20772;
                do
                {
                    uint4 _12915 = r_warped_motion_qdata_tp1.Load(int3(_20107, 0));
                    uint _12916 = _12915.x;
                    if (_12916 != 0u)
                    {
                        float _20771;
                        if (_12916 == 0u)
                        {
                            _20771 = -1.0f;
                        }
                        else
                        {
                            _20771 = float((_12916 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20772 = _20771;
                        break;
                    }
                    int _20754;
                    uint _20755;
                    _20755 = _12916;
                    _20754 = -1;
                    uint _20770;
                    for (; _20754 <= 1; _20755 = _20770, _20754++)
                    {
                        _20770 = _20755;
                        for (int _20768 = -1; _20768 <= 1; )
                        {
                            _20770 = max(_20770, r_warped_motion_qdata_tp1.Load(int3(clamp(_20107 + int2(_20768, _20754), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20768++;
                            continue;
                        }
                    }
                    if (_20755 != 0u)
                    {
                        float _20767;
                        if (_20755 == 0u)
                        {
                            _20767 = -1.0f;
                        }
                        else
                        {
                            _20767 = float((_20755 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20772 = _20767;
                        break;
                    }
                    uint _20757;
                    _20757 = 4294967295u;
                    uint _23652;
                    for (int _20756 = 0; _20756 < 8; _20757 = _23652, _20756++)
                    {
                        int _20760 = 0;
                        for (;;)
                        {
                            if (_20760 < 5)
                            {
                                int2 _12866 = _20107 + (_1243[_20756] * _1252[_20760].xx);
                                bool _12869 = any(bool2(_12866.x < int2(0, 0).x, _12866.y < int2(0, 0).y));
                                bool _12877;
                                if (!_12869)
                                {
                                    _12877 = any(bool2(_12866.x >= cbFI_MvDepthLaneSize.x, _12866.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12877 = _12869;
                                }
                                if (_12877)
                                {
                                    _23652 = _20757;
                                    break;
                                }
                                uint4 _12955 = r_warped_motion_qdata_tp1.Load(int3(_12866, 0));
                                uint _12956 = _12955.x;
                                if (_12956 != 0u)
                                {
                                    _23652 = min(_20757, _12956);
                                    break;
                                }
                                _20760++;
                                continue;
                            }
                            else
                            {
                                _23652 = _20757;
                                break;
                            }
                        }
                    }
                    float _20759;
                    if (_20757 == 4294967295u)
                    {
                        _20759 = -1.0f;
                    }
                    else
                    {
                        float _20758;
                        if (_20757 == 0u)
                        {
                            _20758 = -1.0f;
                        }
                        else
                        {
                            _20758 = float((_20757 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20759 = _20758;
                    }
                    _20772 = _20759;
                    break;
                } while(false);
                bool _6607 = _20772 < 0.0f;
                float _20773;
                if (_6607)
                {
                    _20773 = 0.0f;
                }
                else
                {
                    _20773 = _20772 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12977_dummy_parameter;
                uint _13009_dummy_parameter;
                float4 _20810;
                if ((_6607 && _6596) && _6599)
                {
                    uint _13041_dummy_parameter;
                    float _13065 = log((r_depth_tm1.Load(int3(int2(floor(_19886 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13041_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _13073_dummy_parameter;
                    float _13097 = log((r_depth_tp1.Load(int3(int2(floor(_19888 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13073_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20811;
                    if (_13065 > (_13097 + 0.07999999821186065673828125f))
                    {
                        float4 _19589 = _20777;
                        _19589.x = 0.0f;
                        _20811 = _19589;
                    }
                    else
                    {
                        float4 _20812;
                        if (_13097 > (_13065 + 0.07999999821186065673828125f))
                        {
                            float4 _19591 = _20777;
                            _19591.y = 0.0f;
                            _20812 = _19591;
                        }
                        else
                        {
                            _20812 = _20777;
                        }
                        _20811 = _20812;
                    }
                    _20810 = _20811;
                }
                else
                {
                    _20810 = _20777;
                }
                float _6659 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6661 = _20772 >= 0.0f;
                float _20793;
                if (_6661)
                {
                    _20793 = _20772 - _6659;
                }
                else
                {
                    float _20789;
                    if (_6596)
                    {
                        float _20788;
                        _20788 = 2.0f;
                        float _13155;
                        for (int _20787 = 0; _20787 < 24; _20788 = _13155, _20787++)
                        {
                            float _13119 = float(_20787 & 7) * 0.785398185253143310546875f;
                            int _13121 = _20787 >> 3;
                            int _20790;
                            if (_13121 == 0)
                            {
                                _20790 = 16;
                            }
                            else
                            {
                                _20790 = (_13121 == 1) ? 48 : 96;
                            }
                            uint _13171_dummy_parameter;
                            _13155 = min(_20788, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19886 + ((cbFI_MvDepthLaneSizeRcp * float(_20790)) * float2(cos(_13119), sin(_13119))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13171_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20789 = _20788;
                    }
                    else
                    {
                        _20789 = 0.0f;
                    }
                    _20793 = _20789;
                }
                float _20800;
                if (_6661)
                {
                    _20800 = _20772 - _6659;
                }
                else
                {
                    float _20796;
                    if (_6599)
                    {
                        float _20795;
                        _20795 = 2.0f;
                        float _13269;
                        for (int _20794 = 0; _20794 < 24; _20795 = _13269, _20794++)
                        {
                            float _13233 = float(_20794 & 7) * 0.785398185253143310546875f;
                            int _13235 = _20794 >> 3;
                            int _20797;
                            if (_13235 == 0)
                            {
                                _20797 = 16;
                            }
                            else
                            {
                                _20797 = (_13235 == 1) ? 48 : 96;
                            }
                            uint _13301_dummy_parameter;
                            _13269 = min(_20795, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19888 + ((cbFI_MvDepthLaneSizeRcp * float(_20797)) * float2(cos(_13233), sin(_13233))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13301_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20796 = _20795;
                    }
                    else
                    {
                        _20796 = 0.0f;
                    }
                    _20800 = _20796;
                }
                float _20801;
                if (_6596)
                {
                    uint _13333_dummy_parameter;
                    _20801 = r_depth_tm1.Load(int3(int2(floor(_19886 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13333_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20801 = 0.0f;
                }
                float _20802;
                if (_6599)
                {
                    uint _13352_dummy_parameter;
                    _20802 = r_depth_tp1.Load(int3(int2(floor(_19888 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13352_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20802 = 0.0f;
                }
                bool _6716;
                if (_6596)
                {
                    _6716 = _20801 > ((exp((_20793 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6716 = _6596;
                }
                float4 _20818;
                if (_6716)
                {
                    float4 _19593 = _20810;
                    _19593.x = 0.0f;
                    _20818 = _19593;
                }
                else
                {
                    _20818 = _20810;
                }
                bool _6728;
                if (_6599)
                {
                    _6728 = _20802 > ((exp((_20800 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6728 = _6599;
                }
                float4 _20820;
                if (_6728)
                {
                    float4 _19595 = _20818;
                    _19595.y = 0.0f;
                    _20820 = _19595;
                }
                else
                {
                    _20820 = _20818;
                }
                float4 _20883;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6661)
                {
                    bool _6748;
                    if (_6596)
                    {
                        _6748 = _20801 < ((exp((_20793 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6748 = _6596;
                    }
                    float4 _20822;
                    if (_6748)
                    {
                        float4 _19597 = _20820;
                        _19597.x = 0.0f;
                        _20822 = _19597;
                    }
                    else
                    {
                        _20822 = _20820;
                    }
                    bool _6760;
                    if (_6599)
                    {
                        _6760 = _20802 < ((exp((_20800 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6760 = _6599;
                    }
                    float4 _20884;
                    if (_6760)
                    {
                        float4 _19599 = _20822;
                        _19599.y = 0.0f;
                        _20884 = _19599;
                    }
                    else
                    {
                        _20884 = _20822;
                    }
                    _20883 = _20884;
                }
                else
                {
                    _20883 = _20820;
                }
                _22121 = float3(_20773, log((r_depth_tm1.Load(int3(int2(floor(_19886 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12977_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_19888 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13009_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _20882 = _20883;
            }
            else
            {
                _22121 = float3(0.0f, 0.0f, 0.5f);
                _20882 = _20777;
            }
            bool _6771 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6520;
            bool _6777;
            if (_6771)
            {
                _6777 = _6574 || _6580;
            }
            else
            {
                _6777 = _6771;
            }
            float4 _20925;
            if (_6777)
            {
                float _20877;
                do
                {
                    uint4 _13531 = r_warped_motion_qdata_tp1.Load(int3(_20107, 0));
                    uint _13532 = _13531.x;
                    if (_13532 != 0u)
                    {
                        float _20876;
                        if (_13532 == 0u)
                        {
                            _20876 = -1.0f;
                        }
                        else
                        {
                            _20876 = float((_13532 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20877 = _20876;
                        break;
                    }
                    int _20859;
                    uint _20860;
                    _20860 = _13532;
                    _20859 = -1;
                    uint _20875;
                    for (; _20859 <= 1; _20860 = _20875, _20859++)
                    {
                        _20875 = _20860;
                        for (int _20873 = -1; _20873 <= 1; )
                        {
                            _20875 = max(_20875, r_warped_motion_qdata_tp1.Load(int3(clamp(_20107 + int2(_20873, _20859), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20873++;
                            continue;
                        }
                    }
                    if (_20860 != 0u)
                    {
                        float _20872;
                        if (_20860 == 0u)
                        {
                            _20872 = -1.0f;
                        }
                        else
                        {
                            _20872 = float((_20860 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20877 = _20872;
                        break;
                    }
                    uint _20862;
                    _20862 = 4294967295u;
                    uint _23653;
                    for (int _20861 = 0; _20861 < 8; _20862 = _23653, _20861++)
                    {
                        int _20865 = 0;
                        for (;;)
                        {
                            if (_20865 < 5)
                            {
                                int2 _13482 = _20107 + (_1243[_20861] * _1252[_20865].xx);
                                bool _13485 = any(bool2(_13482.x < int2(0, 0).x, _13482.y < int2(0, 0).y));
                                bool _13493;
                                if (!_13485)
                                {
                                    _13493 = any(bool2(_13482.x >= cbFI_MvDepthLaneSize.x, _13482.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13493 = _13485;
                                }
                                if (_13493)
                                {
                                    _23653 = _20862;
                                    break;
                                }
                                uint4 _13571 = r_warped_motion_qdata_tp1.Load(int3(_13482, 0));
                                uint _13572 = _13571.x;
                                if (_13572 != 0u)
                                {
                                    _23653 = min(_20862, _13572);
                                    break;
                                }
                                _20865++;
                                continue;
                            }
                            else
                            {
                                _23653 = _20862;
                                break;
                            }
                        }
                    }
                    float _20864;
                    if (_20862 == 4294967295u)
                    {
                        _20864 = -1.0f;
                    }
                    else
                    {
                        float _20863;
                        if (_20862 == 0u)
                        {
                            _20863 = -1.0f;
                        }
                        else
                        {
                            _20863 = float((_20862 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20864 = _20863;
                    }
                    _20877 = _20864;
                    break;
                } while(false);
                float4 _20926;
                if (_20877 >= 0.0f)
                {
                    float _13593 = (exp((_20877 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6796;
                    if (_6574)
                    {
                        uint _13600_dummy_parameter;
                        _6796 = r_depth_tm1.Load(int3(int2(floor(_19889 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13600_dummy_parameter))))), 0)).x > _13593;
                    }
                    else
                    {
                        _6796 = _6574;
                    }
                    float4 _20895;
                    if (_6796)
                    {
                        float4 _19601 = _20882;
                        _19601.z = 0.0f;
                        _20895 = _19601;
                    }
                    else
                    {
                        _20895 = _20882;
                    }
                    bool _6808;
                    if (_6580)
                    {
                        uint _13619_dummy_parameter;
                        _6808 = r_depth_tp1.Load(int3(int2(floor(_19890 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13619_dummy_parameter))))), 0)).x > _13593;
                    }
                    else
                    {
                        _6808 = _6580;
                    }
                    float4 _20927;
                    if (_6808)
                    {
                        float4 _19603 = _20895;
                        _19603.w = 0.0f;
                        _20927 = _19603;
                    }
                    else
                    {
                        _20927 = _20895;
                    }
                    _20926 = _20927;
                }
                else
                {
                    _20926 = _20882;
                }
                _20925 = _20926;
            }
            else
            {
                _20925 = _20882;
            }
            bool _6816 = _6562 != _6568;
            bool _6823;
            if (_6816)
            {
                _6823 = _6562 ? _6508 : _6511;
            }
            else
            {
                _6823 = _6816;
            }
            bool _6830;
            if (_6823)
            {
                _6830 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6830 = _6823;
            }
            float4 _21028;
            if (_6830)
            {
                bool2 _6835 = _6562.xx;
                float2 _6836 = float2(_6835.x ? _19886.x : _19888.x, _6835.y ? _19886.y : _19888.y);
                float _20909;
                if (_6562)
                {
                    uint _13638_dummy_parameter;
                    _20909 = r_depth_tm1.Load(int3(int2(floor(_6836 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13638_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13654_dummy_parameter;
                    _20909 = r_depth_tp1.Load(int3(int2(floor(_6836 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13654_dummy_parameter))))), 0)).x;
                }
                float4x4 _20916;
                if (_6562)
                {
                    float4x4 _20905;
                    do
                    {
                        float4x4 _13668;
                        bool _20904;
                        do
                        {
                            _13668 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20904 = false;
                                break;
                            }
                            uint _13702 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13702 + 32u) * 4 + 0) != 1u)
                            {
                                _20904 = false;
                                break;
                            }
                            uint _20901;
                            _20901 = 0u;
                            for (; _20901 < 4u; _20901++)
                            {
                                for (uint _20902 = 0u; _20902 < 4u; )
                                {
                                    _13668[_20901][_20902] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13702 + 16u) + (_20901 * 4u)) + _20902) * 4 + 0));
                                    _20902++;
                                    continue;
                                }
                            }
                            _20904 = true;
                            break;
                        } while(false);
                        if (_20904)
                        {
                            _20905 = _13668;
                            break;
                        }
                        _20905 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20916 = _20905;
                }
                else
                {
                    float4x4 _20900;
                    do
                    {
                        float4x4 _13774;
                        bool _20899;
                        do
                        {
                            _13774 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20899 = false;
                                break;
                            }
                            uint _13808 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13808 + 32u) * 4 + 0) != 1u)
                            {
                                _20899 = false;
                                break;
                            }
                            uint _20896;
                            _20896 = 0u;
                            for (; _20896 < 4u; _20896++)
                            {
                                for (uint _20897 = 0u; _20897 < 4u; )
                                {
                                    _13774[_20896][_20897] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13808 + (_20896 * 4u)) + _20897) * 4 + 0));
                                    _20897++;
                                    continue;
                                }
                            }
                            _20899 = true;
                            break;
                        } while(false);
                        if (_20899)
                        {
                            _20900 = _13774;
                            break;
                        }
                        _20900 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20916 = _20900;
                }
                float2 _20917;
                do
                {
                    float _13885 = _6836.x;
                    float _13888 = 1.0f - _6836.y;
                    float4 _13899 = mul(float4((float2(_13885, _13888) * 2.0f) - 1.0f.xx, _20909, 1.0f), _20916);
                    float _13901 = _13899.w;
                    if (!(_13901 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20917 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13914 = ((_13899.xy / _13901.xx) + 1.0f.xx) * 0.5f;
                    _20917 = float2(_13914.x - _13885, _13888 - _13914.y);
                    break;
                } while(false);
                float2 _6866 = float2(cbFI_DisplaySize);
                float4 _21029;
                if (!(length(((_6836 + _20917) - float2(_6835.x ? _19888.x : _19886.x, _6835.y ? _19888.y : _19886.y)) * _6866) <= ((0.100000001490116119384765625f * length(_20917 * _6866)) + 8.0f)))
                {
                    float4 _21030;
                    if (_6562)
                    {
                        float4 _19613 = _20925;
                        _19613.x = 0.0f;
                        _21030 = _19613;
                    }
                    else
                    {
                        float4 _19615 = _20925;
                        _19615.y = 0.0f;
                        _21030 = _19615;
                    }
                    _21029 = _21030;
                }
                else
                {
                    _21029 = _20925;
                }
                _21028 = _21029;
            }
            else
            {
                _21028 = _20925;
            }
            float4 _6891 = _20639 * _21028;
            float _6893 = dot(_6891, 1.0f.xxxx);
            float4 _21370;
            bool _21676;
            if (_6893 > 0.0f)
            {
                _21676 = _20330;
                _21370 = _6891 / _6893.xxxx;
            }
            else
            {
                bool _6904 = any(bool4(_21028.x < 1.0f.xxxx.x, _21028.y < 1.0f.xxxx.y, _21028.z < 1.0f.xxxx.z, _21028.w < 1.0f.xxxx.w));
                if (_6904)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13936;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13936);
                    }
                }
                bool4 _23766 = _6904.xxxx;
                _21676 = _6904 ? true : _20330;
                _21370 = float4(_23766.x ? 0.0f.xxxx.x : _20639.x, _23766.y ? 0.0f.xxxx.y : _20639.y, _23766.z ? 0.0f.xxxx.z : _20639.z, _23766.w ? 0.0f.xxxx.w : _20639.w);
            }
            _22012 = _22121;
            _21675 = _21676;
            _21369 = _21370;
        }
        else
        {
            _22012 = float3(0.0f, 0.0f, 0.5f);
            _21675 = _20330;
            _21369 = _20639;
        }
        uint _6913 = (cbFI_pad0 >> 24u) & 31u;
        uint _6917 = (cbFI_pad0 >> 16u) & 255u;
        bool _6919 = _6913 != 0u;
        bool _6921 = _6917 == 12u;
        bool _6924 = _6917 == 13u;
        float4 _21390;
        if ((_6919 || _6921) || _6924)
        {
            float _21036;
            do
            {
                bool _14020 = all(bool2(_19889.x > 0.0f.xx.x, _19889.y > 0.0f.xx.y));
                bool _14026;
                if (_14020)
                {
                    _14026 = all(bool2(_19889.x < 1.0f.xx.x, _19889.y < 1.0f.xx.y));
                }
                else
                {
                    _14026 = _14020;
                }
                bool _13957 = !_14026;
                bool _13964;
                if (!_13957)
                {
                    bool _14031 = all(bool2(_19890.x > 0.0f.xx.x, _19890.y > 0.0f.xx.y));
                    bool _14037;
                    if (_14031)
                    {
                        _14037 = all(bool2(_19890.x < 1.0f.xx.x, _19890.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _14037 = _14031;
                    }
                    _13964 = !_14037;
                }
                else
                {
                    _13964 = _13957;
                }
                if (_13964)
                {
                    _21036 = 0.0f;
                    break;
                }
                uint _14044_dummy_parameter;
                uint _14060_dummy_parameter;
                float4x4 _21035;
                do
                {
                    float4x4 _14074;
                    bool _21034;
                    do
                    {
                        _14074 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _21034 = false;
                            break;
                        }
                        uint _14108 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14108 + 32u) * 4 + 0) != 1u)
                        {
                            _21034 = false;
                            break;
                        }
                        uint _21031;
                        _21031 = 0u;
                        for (; _21031 < 4u; _21031++)
                        {
                            for (uint _21032 = 0u; _21032 < 4u; )
                            {
                                _14074[_21031][_21032] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14108 + 16u) + (_21031 * 4u)) + _21032) * 4 + 0));
                                _21032++;
                                continue;
                            }
                        }
                        _21034 = true;
                        break;
                    } while(false);
                    if (_21034)
                    {
                        _21035 = _14074;
                        break;
                    }
                    _21035 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13985 = mul(float4((float2(_19889.x, 1.0f - _19889.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19889 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14044_dummy_parameter))))), 0)).x, 1.0f), _21035);
                float _13987 = _13985.w;
                if (abs(_13987) < 9.9999999747524270787835121154785e-07f)
                {
                    _21036 = 0.0f;
                    break;
                }
                float _13998 = abs(cbFI_DeviceToViewDepth.y / ((_13985.z / _13987) - cbFI_DeviceToViewDepth.x));
                float _14001 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19890 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _14060_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _21036 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13998 - _14001) / max(max(_13998, _14001), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14210 = all(bool2(_19890.x > 0.0f.xx.x, _19890.y > 0.0f.xx.y));
            bool _14216;
            if (_14210)
            {
                _14216 = all(bool2(_19890.x < 1.0f.xx.x, _19890.y < 1.0f.xx.y));
            }
            else
            {
                _14216 = _14210;
            }
            float _21037;
            if (_14216)
            {
                uint _14223_dummy_parameter;
                _21037 = length((_8044 + (r_motion_tp1.Load(int3(int2(floor(_19890 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14223_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _21037 = 1000000.0f;
            }
            float _21052;
            if ((_6913 & 1u) != 0u)
            {
                _21052 = _21036;
            }
            else
            {
                _21052 = 1.0f;
            }
            float _21053;
            if ((_6913 & 2u) != 0u)
            {
                _21053 = _21052 * (1.0f - smoothstep(2.0f, 8.0f, _21037));
            }
            else
            {
                _21053 = _21052;
            }
            float _21054;
            if ((_6913 & 4u) != 0u)
            {
                _21054 = _21053 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8765 - _8773) - length(_8749 - _8757))));
            }
            else
            {
                _21054 = _21053;
            }
            float _21384;
            if ((_6913 & 8u) != 0u)
            {
                _21384 = lerp(1.0f, _21054, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8749 - _8757)));
            }
            else
            {
                _21384 = _21054;
            }
            bool _6999 = (_6913 & 16u) != 0u;
            bool _7008;
            if (_6999)
            {
                _7008 = length(_19884 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _7008 = _6999;
            }
            float _23768 = _7008 ? 1.0f : _21384;
            bool _7014 = _6919 && _11146;
            bool _7019;
            if (_7014)
            {
                bool _14248 = all(bool2(_19886.x > 0.0f.xx.x, _19886.y > 0.0f.xx.y));
                bool _14254;
                if (_14248)
                {
                    _14254 = all(bool2(_19886.x < 1.0f.xx.x, _19886.y < 1.0f.xx.y));
                }
                else
                {
                    _14254 = _14248;
                }
                _7019 = _14254;
            }
            else
            {
                _7019 = _7014;
            }
            bool _7024;
            if (_7019)
            {
                bool _14259 = all(bool2(_19888.x > 0.0f.xx.x, _19888.y > 0.0f.xx.y));
                bool _14265;
                if (_14259)
                {
                    _14265 = all(bool2(_19888.x < 1.0f.xx.x, _19888.y < 1.0f.xx.y));
                }
                else
                {
                    _14265 = _14259;
                }
                _7024 = _14265;
            }
            else
            {
                _7024 = _7019;
            }
            float4 _21391;
            if (_7024)
            {
                float _7030 = _21369.x + _21369.y;
                float _7039 = (_21369.z + _21369.w) * (1.0f - _23768);
                float _21387;
                if (_7030 > 9.9999997473787516355514526367188e-06f)
                {
                    _21387 = _21369.x / _7030;
                }
                else
                {
                    _21387 = _5769;
                }
                _21391 = float4(_21369.x + (_7039 * _21387), _21369.y + (_7039 * (1.0f - _21387)), _21369.zw * _23768);
            }
            else
            {
                _21391 = _21369;
            }
            _21390 = _21391;
        }
        else
        {
            _21390 = _21369;
        }
        float3 _7100 = (((_8749 * _21390.x) + (_8757 * _21390.y)) + (_8765 * _21390.z)) + (_8773 * _21390.w);
        float3 _23401;
        if (_5785 && (_21405 > 0.0f))
        {
            uint _14272_dummy_parameter;
            float2 _14287 = r_motion_tp1.Load(int3(int2(floor(_5544 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14272_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21667;
            if (_8072)
            {
                float2 _14332 = clamp((((_19863 + (_14287 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14335 = tan(_14332.x);
                _21667 = (float2(_14335 / cbFI_DeviceToViewDepth.z, (tan(_14332.y) * sqrt(1.0f + (_14335 * _14335))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21667 = _19863 + (_14287 * cbFI_Timestep);
            }
            float2 _21668;
            if (_8072)
            {
                float2 _14411 = clamp((((_19863 + (_14287 * _5759)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14414 = tan(_14411.x);
                _21668 = (float2(_14414 / cbFI_DeviceToViewDepth.z, (tan(_14411.y) * sqrt(1.0f + (_14414 * _14414))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21668 = _19863 + (_14287 * _5759);
            }
            _23401 = lerp(_7100, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21667, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21668, 0.0f).xyz, cbFI_Timestep.xxx), _21405.xxx);
        }
        else
        {
            _23401 = _7100;
        }
        float3 _23400;
        if (_21675)
        {
            float3 _14456 = r_current_interpolation_source.Load(int3(_5045, 0)).xyz;
            float3 _23402;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11146)
            {
                uint _14463_dummy_parameter;
                float _21798;
                _21798 = r_depth_tm1.Load(int3(int2(floor(_19886 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14463_dummy_parameter))))), 0)).x;
                float _7181;
                for (int _21797 = 0; _21797 < 24; _21798 = _7181, _21797++)
                {
                    float _7153 = float(_21797 & 7) * 0.785398185253143310546875f;
                    int _7155 = _21797 >> 3;
                    int _23495;
                    if (_7155 == 0)
                    {
                        _23495 = 16;
                    }
                    else
                    {
                        _23495 = (_7155 == 1) ? 48 : 96;
                    }
                    uint _14483_dummy_parameter;
                    _7181 = min(_21798, r_depth_tm1.Load(int3(int2(floor(clamp(_19886 + ((cbFI_MvDepthLaneSizeRcp * float(_23495)) * float2(cos(_7153), sin(_7153))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14483_dummy_parameter))))), 0)).x);
                }
                float2 _21799;
                do
                {
                    float _14505 = 1.0f - _19886.y;
                    float4 _14516 = mul(float4((float2(_19886.x, _14505) * 2.0f) - 1.0f.xx, _21798, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14518 = _14516.w;
                    if (!(_14518 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21799 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14531 = ((_14516.xy / _14518.xx) + 1.0f.xx) * 0.5f;
                    _21799 = float2(_14531.x - _19886.x, _14505 - _14531.y);
                    break;
                } while(false);
                float2 _7192 = _19886 + _21799;
                bool _14549 = all(bool2(_7192.x > 0.0f.xx.x, _7192.y > 0.0f.xx.y));
                bool _14555;
                if (_14549)
                {
                    _14555 = all(bool2(_7192.x < 1.0f.xx.x, _7192.y < 1.0f.xx.y));
                }
                else
                {
                    _14555 = _14549;
                }
                float3 _23403;
                if (_14555)
                {
                    float _7198 = abs(cbFI_DeviceToViewDepth.y / (_21798 - cbFI_DeviceToViewDepth.x));
                    uint _14575_dummy_parameter;
                    int2 _14575 = int2(spvTextureSize(r_depth_m2, uint(0), _14575_dummy_parameter));
                    float _7202 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7192 * float2(_14575))), int2(0, 0), _14575 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _23408;
                    if (abs(_7202 - _7198) <= (0.20000000298023223876953125f * max(_7202, _7198)))
                    {
                        uint _14609_dummy_parameter;
                        int2 _14609 = int2(spvTextureSize(r_colour_m2, uint(0), _14609_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14632;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14632);
                        }
                        _23408 = r_colour_m2.Load(int3(clamp(int2(floor(_7192 * float2(_14609))), int2(0, 0), _14609 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14642;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14642);
                        }
                        _23408 = _14456;
                    }
                    _23403 = _23408;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14652;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14652);
                    }
                    _23403 = _14456;
                }
                _23402 = _23403;
            }
            else
            {
                _23402 = _14456;
            }
            _23400 = _23402;
        }
        else
        {
            _23400 = _23401;
        }
        bool _7227 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _23399;
        float _23475;
        if (_7227)
        {
            float2 _7231 = float2(cbFI_DisplaySize);
            float3 _21987;
            float _21988;
            do
            {
                bool _15068;
                float4x4 _21806;
                do
                {
                    float4x4 _15044;
                    bool _21805;
                    do
                    {
                        _15044 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _15068 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_15068)
                        {
                            _21805 = false;
                            break;
                        }
                        uint _15078 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_15078 + 32u) * 4 + 0) != 1u)
                        {
                            _21805 = false;
                            break;
                        }
                        uint _21802;
                        _21802 = 0u;
                        for (; _21802 < 4u; _21802++)
                        {
                            for (uint _21803 = 0u; _21803 < 4u; )
                            {
                                _15044[_21802][_21803] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15078 + (_21802 * 4u)) + _21803) * 4 + 0));
                                _21803++;
                                continue;
                            }
                        }
                        _21805 = true;
                        break;
                    } while(false);
                    if (_21805)
                    {
                        _21806 = _15044;
                        break;
                    }
                    _21806 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float4x4 _14656 = _21806;
                float4x4 _14728 = spvInverse(_21806);
                float4x4 _14657 = _14728;
                if (_6917 == 35u)
                {
                    int2 _14735 = int2(_5544 * _7231);
                    bool _14742 = _14735.y != (int(_7231.y) / 2);
                    bool _14749;
                    if (!_14742)
                    {
                        _14749 = _14735.x >= 80;
                    }
                    else
                    {
                        _14749 = _14742;
                    }
                    if (_14749)
                    {
                        _21988 = 2.0f;
                        _21987 = 0.0f.xxx;
                        break;
                    }
                    int _14753 = _14735.x;
                    int _14754 = _14753 / 2;
                    float _21981;
                    if (_14754 < 16)
                    {
                        _21981 = _14656[_14754 / 4][_14754 % 4];
                    }
                    else
                    {
                        float _21982;
                        if (_14754 < 32)
                        {
                            int _14769 = _14754 - 16;
                            _21982 = _14657[_14769 / 4][_14769 % 4];
                        }
                        else
                        {
                            float _21983;
                            if (_14754 < 36)
                            {
                                _21983 = cbFI_DeviceToViewDepth[_14754 - 32];
                            }
                            else
                            {
                                float _21984;
                                if (_14754 == 36)
                                {
                                    _21984 = float(cbFI_RenderSize.x);
                                }
                                else
                                {
                                    float _21985;
                                    if (_14754 == 37)
                                    {
                                        _21985 = float(cbFI_RenderSize.y);
                                    }
                                    else
                                    {
                                        _21985 = 0.0f;
                                    }
                                    _21984 = _21985;
                                }
                                _21983 = _21984;
                            }
                            _21982 = _21983;
                        }
                        _21981 = _21982;
                    }
                    uint _14804 = asuint(_21981);
                    uint _21986;
                    if ((_14753 & 1) == 0)
                    {
                        _21986 = _14804 >> 16u;
                    }
                    else
                    {
                        _21986 = _14804 & 65535u;
                    }
                    _21988 = 2.0f;
                    _21987 = float3(float(_21986 >> 8u) * 0.0039215688593685626983642578125f, float(_21986 & 255u) * 0.0039215688593685626983642578125f, 0.0f);
                    break;
                }
                bool _14828 = _6917 == 33u;
                if (_14828 || (_6917 == 34u))
                {
                    uint _15166_dummy_parameter;
                    float2 _15181 = r_motion_tp1.Load(int3(int2(floor(clamp(_5544, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15166_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
                    float2 _21973;
                    if (_14828)
                    {
                        uint _15193_dummy_parameter;
                        float2 _21972;
                        do
                        {
                            float _15212 = _5544.x;
                            float _15215 = 1.0f - _5544.y;
                            float4 _15226 = mul(float4((float2(_15212, _15215) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5544 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15193_dummy_parameter))))), 0)).x, 1.0f), _21806);
                            float _15228 = _15226.w;
                            if (!(_15228 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21972 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15241 = ((_15226.xy / _15228.xx) + 1.0f.xx) * 0.5f;
                            _21972 = float2(_15241.x - _15212, _15215 - _15241.y);
                            break;
                        } while(false);
                        _21973 = _21972 - _15181;
                    }
                    else
                    {
                        float2 _14848 = _5544 + _15181;
                        bool _15259 = all(bool2(_14848.x > 0.0f.xx.x, _14848.y > 0.0f.xx.y));
                        bool _15265;
                        if (_15259)
                        {
                            _15265 = all(bool2(_14848.x < 1.0f.xx.x, _14848.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15265 = _15259;
                        }
                        float2 _21971;
                        if (_15265)
                        {
                            uint _15272_dummy_parameter;
                            float2 _21970;
                            do
                            {
                                float _15291 = _14848.x;
                                float _15294 = 1.0f - _14848.y;
                                float4 _15305 = mul(float4((float2(_15291, _15294) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14848 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _15272_dummy_parameter))))), 0)).x, 1.0f), _14728);
                                float _15307 = _15305.w;
                                if (!(_15307 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21970 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _15320 = ((_15305.xy / _15307.xx) + 1.0f.xx) * 0.5f;
                                _21970 = float2(_15320.x - _15291, _15294 - _15320.y);
                                break;
                            } while(false);
                            _21971 = _21970 + _15181;
                        }
                        else
                        {
                            _21971 = 0.0f.xx;
                        }
                        _21973 = _21971;
                    }
                    bool _21980;
                    do
                    {
                        bool _15399 = all(bool2(_5544.x > 0.0f.xx.x, _5544.y > 0.0f.xx.y));
                        bool _15405;
                        if (_15399)
                        {
                            _15405 = all(bool2(_5544.x < 1.0f.xx.x, _5544.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15405 = _15399;
                        }
                        if (!_15405)
                        {
                            _21980 = false;
                            break;
                        }
                        uint _15412_dummy_parameter;
                        float4x4 _21978;
                        do
                        {
                            float4x4 _15426;
                            bool _21977;
                            do
                            {
                                _15426 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_15068)
                                {
                                    _21977 = false;
                                    break;
                                }
                                uint _15460 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_15460 + 32u) * 4 + 0) != 1u)
                                {
                                    _21977 = false;
                                    break;
                                }
                                uint _21974;
                                _21974 = 0u;
                                for (; _21974 < 4u; _21974++)
                                {
                                    for (uint _21975 = 0u; _21975 < 4u; )
                                    {
                                        _15426[_21974][_21975] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15460 + (_21974 * 4u)) + _21975) * 4 + 0));
                                        _21975++;
                                        continue;
                                    }
                                }
                                _21977 = true;
                                break;
                            } while(false);
                            if (_21977)
                            {
                                _21978 = _15426;
                                break;
                            }
                            _21978 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21979;
                        do
                        {
                            float _15537 = _5544.x;
                            float _15540 = 1.0f - _5544.y;
                            float4 _15551 = mul(float4((float2(_15537, _15540) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5544 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15412_dummy_parameter))))), 0)).x, 1.0f), _21978);
                            float _15553 = _15551.w;
                            if (!(_15553 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21979 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15566 = ((_15551.xy / _15553.xx) + 1.0f.xx) * 0.5f;
                            _21979 = float2(_15566.x - _15537, _15540 - _15566.y);
                            break;
                        } while(false);
                        float2 _15363 = abs(_21979);
                        if (any(bool2(_15363.x > 100000.0f.xx.x, _15363.y > 100000.0f.xx.y)))
                        {
                            _21980 = false;
                            break;
                        }
                        float _15371 = length(_21979 * _7231);
                        uint _15586_dummy_parameter;
                        bool _15385 = _15371 > ((8.0f * _7231.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _15392;
                        if (_15385)
                        {
                            _15392 = length((r_motion_tp1.Load(int3(int2(floor(_5544 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15586_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7231) < (0.20000000298023223876953125f * _15371);
                        }
                        else
                        {
                            _15392 = _15385;
                        }
                        _21980 = _15392;
                        break;
                    } while(false);
                    _21988 = 2.0f;
                    _21987 = float3(clamp(length(_21973 * float2(cbFI_RenderSize)) * 0.25f, 0.0f, 1.0f), float(_21980), 0.0f);
                    break;
                }
                float _15620;
                float _15623;
                float4 _15633;
                float2 _21807;
                do
                {
                    _15620 = _5544.x;
                    _15623 = 1.0f - _5544.y;
                    _15633 = float4((float2(_15620, _15623) * 2.0f) - 1.0f.xx, 1.0000000116860974230803549289703e-07f, 1.0f);
                    float4 _15634 = mul(_15633, _21806);
                    float _15636 = _15634.w;
                    if (!(_15636 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21807 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15649 = ((_15634.xy / _15636.xx) + 1.0f.xx) * 0.5f;
                    _21807 = float2(_15649.x - _15620, _15623 - _15649.y);
                    break;
                } while(false);
                float2 _21808;
                do
                {
                    float4 _15686 = mul(_15633, _14728);
                    float _15688 = _15686.w;
                    if (!(_15688 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21808 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15701 = ((_15686.xy / _15688.xx) + 1.0f.xx) * 0.5f;
                    _21808 = float2(_15701.x - _15620, _15623 - _15701.y);
                    break;
                } while(false);
                float2 _14883 = abs(_21807);
                bool2 _23769 = any(bool2(_14883.x > 4.0f.xx.x, _14883.y > 4.0f.xx.y)).xx;
                float2 _14889 = abs(_21808);
                bool2 _23771 = any(bool2(_14889.x > 4.0f.xx.x, _14889.y > 4.0f.xx.y)).xx;
                float2 _15715[3];
                _15715[0] = _5544;
                float2 _15835 = clamp(_5544, 0.0f.xx, 1.0f.xx);
                uint _15843_dummy_parameter;
                _15715[1] = _5544 - ((r_motion_tp1.Load(int3(int2(floor(_15835 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15843_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5769);
                _15715[2] = _5544 - (float2(_23769.x ? 0.0f.xx.x : _21807.x, _23769.y ? 0.0f.xx.y : _21807.y) * _5769);
                float _21814;
                float2 _21815;
                _21815 = _5544;
                _21814 = 1000000000.0f;
                float _23773;
                float2 _23775;
                float _23776;
                int _21813 = 0;
                float _21962 = -1.0f;
                for (; _21813 < 3; _21962 = _23773, _21815 = _23775, _21814 = _23776, _21813++)
                {
                    float2 _21952;
                    _21952 = _15715[_21813];
                    for (int _21951 = 0; _21951 < 30; )
                    {
                        uint _16357_dummy_parameter;
                        _21952 += (((_5544 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_21952, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16357_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5769)) - _21952) * 0.699999988079071044921875f);
                        _21951++;
                        continue;
                    }
                    float2 _16787 = clamp(_21952, 0.0f.xx, 1.0f.xx);
                    uint _16795_dummy_parameter;
                    bool _17225 = all(bool2(_21952.x > 0.0f.xx.x, _21952.y > 0.0f.xx.y));
                    bool _17231;
                    if (_17225)
                    {
                        _17231 = all(bool2(_21952.x < 1.0f.xx.x, _21952.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17231 = _17225;
                    }
                    float _21954;
                    if (_17231)
                    {
                        _21954 = length(((_21952 + ((r_motion_tp1.Load(int3(int2(floor(_16787 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16795_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5769)) - _5544) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21954 = 1000000000.0f;
                    }
                    uint _17242_dummy_parameter;
                    float _17282 = log((r_depth_tp1.Load(int3(int2(floor(_16787 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17242_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15795 = _21954 < 0.3499999940395355224609375f;
                    bool _15797 = _21814 < 0.3499999940395355224609375f;
                    bool _15807;
                    if (_15795)
                    {
                        _15807 = (!_15797) || (_17282 > _21962);
                    }
                    else
                    {
                        _15807 = _15795;
                    }
                    bool _15820;
                    if (!_15807)
                    {
                        _15820 = ((!_15795) && (!_15797)) && (_21954 < _21814);
                    }
                    else
                    {
                        _15820 = _15807;
                    }
                    _23773 = _15820 ? _17282 : _21962;
                    bool2 _23774 = _15820.xx;
                    _23775 = float2(_23774.x ? _21952.x : _21815.x, _23774.y ? _21952.y : _21815.y);
                    _23776 = _15820 ? _21954 : _21814;
                }
                float2 _17284[3];
                _17284[0] = _5544;
                float2 _21834;
                do
                {
                    bool _21824;
                    do
                    {
                        bool _17531 = all(bool2(_15835.x > 0.0f.xx.x, _15835.y > 0.0f.xx.y));
                        bool _17537;
                        if (_17531)
                        {
                            _17537 = all(bool2(_15835.x < 1.0f.xx.x, _15835.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17537 = _17531;
                        }
                        if (!_17537)
                        {
                            _21824 = false;
                            break;
                        }
                        uint _17544_dummy_parameter;
                        float4x4 _21822;
                        do
                        {
                            float4x4 _17558;
                            bool _21821;
                            do
                            {
                                _17558 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_15068)
                                {
                                    _21821 = false;
                                    break;
                                }
                                uint _17592 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17592 + 32u) * 4 + 0) != 1u)
                                {
                                    _21821 = false;
                                    break;
                                }
                                uint _21818;
                                _21818 = 0u;
                                for (; _21818 < 4u; _21818++)
                                {
                                    for (uint _21819 = 0u; _21819 < 4u; )
                                    {
                                        _17558[_21818][_21819] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17592 + (_21818 * 4u)) + _21819) * 4 + 0));
                                        _21819++;
                                        continue;
                                    }
                                }
                                _21821 = true;
                                break;
                            } while(false);
                            if (_21821)
                            {
                                _21822 = _17558;
                                break;
                            }
                            _21822 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21823;
                        do
                        {
                            float _17669 = _15835.x;
                            float _17672 = 1.0f - _15835.y;
                            float4 _17683 = mul(float4((float2(_17669, _17672) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15835 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17544_dummy_parameter))))), 0)).x, 1.0f), _21822);
                            float _17685 = _17683.w;
                            if (!(_17685 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21823 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17698 = ((_17683.xy / _17685.xx) + 1.0f.xx) * 0.5f;
                            _21823 = float2(_17698.x - _17669, _17672 - _17698.y);
                            break;
                        } while(false);
                        float2 _17495 = abs(_21823);
                        if (any(bool2(_17495.x > 100000.0f.xx.x, _17495.y > 100000.0f.xx.y)))
                        {
                            _21824 = false;
                            break;
                        }
                        float _17503 = length(_21823 * _7231);
                        uint _17718_dummy_parameter;
                        bool _17517 = _17503 > ((8.0f * _7231.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17524;
                        if (_17517)
                        {
                            _17524 = length((r_motion_tp1.Load(int3(int2(floor(_15835 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17718_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7231) < (0.20000000298023223876953125f * _17503);
                        }
                        else
                        {
                            _17524 = _17517;
                        }
                        _21824 = _17524;
                        break;
                    } while(false);
                    if (_21824)
                    {
                        uint _17749_dummy_parameter;
                        _21834 = -(r_motion_tp1.Load(int3(int2(floor(_15835 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17749_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17776_dummy_parameter;
                    float2 _21833;
                    do
                    {
                        float _17795 = _15835.x;
                        float _17798 = 1.0f - _15835.y;
                        float4 _17809 = mul(float4((float2(_17795, _17798) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15835 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17776_dummy_parameter))))), 0)).x, 1.0f), _14728);
                        float _17811 = _17809.w;
                        if (!(_17811 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21833 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17824 = ((_17809.xy / _17811.xx) + 1.0f.xx) * 0.5f;
                        _21833 = float2(_17824.x - _17795, _17798 - _17824.y);
                        break;
                    } while(false);
                    float2 _17462 = abs(_21833);
                    bool2 _17466 = any(bool2(_17462.x > 4.0f.xx.x, _17462.y > 4.0f.xx.y)).xx;
                    _21834 = float2(_17466.x ? 0.0f.xx.x : _21833.x, _17466.y ? 0.0f.xx.y : _21833.y);
                    break;
                } while(false);
                _17284[1] = _5544 - (_21834 * cbFI_Timestep);
                _17284[2] = _5544 - (float2(_23771.x ? 0.0f.xx.x : _21808.x, _23771.y ? 0.0f.xx.y : _21808.y) * cbFI_Timestep);
                float _21836;
                float2 _21837;
                _21837 = _5544;
                _21836 = 1000000000.0f;
                float _23777;
                float2 _23779;
                float _23780;
                float4x4 _18072;
                float4x4 _18510;
                int _21835 = 0;
                float _21889 = -1.0f;
                for (; _21835 < 3; _21889 = _23777, _21837 = _23779, _21836 = _23780, _21835++)
                {
                    float2 _21839;
                    _21839 = _17284[_21835];
                    float2 _17881;
                    for (int _21838 = 0; _21838 < 30; _21839 = _17881, _21838++)
                    {
                        float2 _21930;
                        do
                        {
                            float2 _17961 = clamp(_21839, 0.0f.xx, 1.0f.xx);
                            bool _21920;
                            do
                            {
                                bool _18045 = all(bool2(_17961.x > 0.0f.xx.x, _17961.y > 0.0f.xx.y));
                                bool _18051;
                                if (_18045)
                                {
                                    _18051 = all(bool2(_17961.x < 1.0f.xx.x, _17961.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _18051 = _18045;
                                }
                                if (!_18051)
                                {
                                    _21920 = false;
                                    break;
                                }
                                uint _18058_dummy_parameter;
                                float4x4 _21918;
                                do
                                {
                                    bool _21917;
                                    do
                                    {
                                        _18072 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_15068)
                                        {
                                            _21917 = false;
                                            break;
                                        }
                                        uint _18106 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_18106 + 32u) * 4 + 0) != 1u)
                                        {
                                            _21917 = false;
                                            break;
                                        }
                                        uint _21914;
                                        _21914 = 0u;
                                        for (; _21914 < 4u; _21914++)
                                        {
                                            for (uint _21915 = 0u; _21915 < 4u; )
                                            {
                                                _18072[_21914][_21915] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18106 + (_21914 * 4u)) + _21915) * 4 + 0));
                                                _21915++;
                                                continue;
                                            }
                                        }
                                        _21917 = true;
                                        break;
                                    } while(false);
                                    if (_21917)
                                    {
                                        _21918 = _18072;
                                        break;
                                    }
                                    _21918 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _21919;
                                do
                                {
                                    float _18183 = _17961.x;
                                    float _18186 = 1.0f - _17961.y;
                                    float4 _18197 = mul(float4((float2(_18183, _18186) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17961 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18058_dummy_parameter))))), 0)).x, 1.0f), _21918);
                                    float _18199 = _18197.w;
                                    if (!(_18199 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _21919 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _18212 = ((_18197.xy / _18199.xx) + 1.0f.xx) * 0.5f;
                                    _21919 = float2(_18212.x - _18183, _18186 - _18212.y);
                                    break;
                                } while(false);
                                float2 _18009 = abs(_21919);
                                if (any(bool2(_18009.x > 100000.0f.xx.x, _18009.y > 100000.0f.xx.y)))
                                {
                                    _21920 = false;
                                    break;
                                }
                                float _18017 = length(_21919 * _7231);
                                uint _18232_dummy_parameter;
                                bool _18031 = _18017 > ((8.0f * _7231.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _18038;
                                if (_18031)
                                {
                                    _18038 = length((r_motion_tp1.Load(int3(int2(floor(_17961 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18232_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7231) < (0.20000000298023223876953125f * _18017);
                                }
                                else
                                {
                                    _18038 = _18031;
                                }
                                _21920 = _18038;
                                break;
                            } while(false);
                            if (_21920)
                            {
                                uint _18263_dummy_parameter;
                                _21930 = -(r_motion_tp1.Load(int3(int2(floor(_17961 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18263_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _18290_dummy_parameter;
                            float2 _21929;
                            do
                            {
                                float _18309 = _17961.x;
                                float _18312 = 1.0f - _17961.y;
                                float4 _18323 = mul(float4((float2(_18309, _18312) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17961 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18290_dummy_parameter))))), 0)).x, 1.0f), _14728);
                                float _18325 = _18323.w;
                                if (!(_18325 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21929 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18338 = ((_18323.xy / _18325.xx) + 1.0f.xx) * 0.5f;
                                _21929 = float2(_18338.x - _18309, _18312 - _18338.y);
                                break;
                            } while(false);
                            float2 _17976 = abs(_21929);
                            bool2 _17980 = any(bool2(_17976.x > 4.0f.xx.x, _17976.y > 4.0f.xx.y)).xx;
                            _21930 = float2(_17980.x ? 0.0f.xx.x : _21929.x, _17980.y ? 0.0f.xx.y : _21929.y);
                            break;
                        } while(false);
                        _17881 = _21839 + (((_5544 - (_21930 * cbFI_Timestep)) - _21839) * 0.699999988079071044921875f);
                    }
                    float2 _18399;
                    float2 _21856;
                    do
                    {
                        _18399 = clamp(_21839, 0.0f.xx, 1.0f.xx);
                        bool _21846;
                        do
                        {
                            bool _18483 = all(bool2(_18399.x > 0.0f.xx.x, _18399.y > 0.0f.xx.y));
                            bool _18489;
                            if (_18483)
                            {
                                _18489 = all(bool2(_18399.x < 1.0f.xx.x, _18399.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18489 = _18483;
                            }
                            if (!_18489)
                            {
                                _21846 = false;
                                break;
                            }
                            uint _18496_dummy_parameter;
                            float4x4 _21844;
                            do
                            {
                                bool _21843;
                                do
                                {
                                    _18510 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_15068)
                                    {
                                        _21843 = false;
                                        break;
                                    }
                                    uint _18544 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18544 + 32u) * 4 + 0) != 1u)
                                    {
                                        _21843 = false;
                                        break;
                                    }
                                    uint _21840;
                                    _21840 = 0u;
                                    for (; _21840 < 4u; _21840++)
                                    {
                                        for (uint _21841 = 0u; _21841 < 4u; )
                                        {
                                            _18510[_21840][_21841] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18544 + (_21840 * 4u)) + _21841) * 4 + 0));
                                            _21841++;
                                            continue;
                                        }
                                    }
                                    _21843 = true;
                                    break;
                                } while(false);
                                if (_21843)
                                {
                                    _21844 = _18510;
                                    break;
                                }
                                _21844 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _21845;
                            do
                            {
                                float _18624 = 1.0f - _18399.y;
                                float4 _18635 = mul(float4((float2(_18399.x, _18624) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18399 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18496_dummy_parameter))))), 0)).x, 1.0f), _21844);
                                float _18637 = _18635.w;
                                if (!(_18637 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21845 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18650 = ((_18635.xy / _18637.xx) + 1.0f.xx) * 0.5f;
                                _21845 = float2(_18650.x - _18399.x, _18624 - _18650.y);
                                break;
                            } while(false);
                            float2 _18447 = abs(_21845);
                            if (any(bool2(_18447.x > 100000.0f.xx.x, _18447.y > 100000.0f.xx.y)))
                            {
                                _21846 = false;
                                break;
                            }
                            float _18455 = length(_21845 * _7231);
                            uint _18670_dummy_parameter;
                            bool _18469 = _18455 > ((8.0f * _7231.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18476;
                            if (_18469)
                            {
                                _18476 = length((r_motion_tp1.Load(int3(int2(floor(_18399 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18670_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7231) < (0.20000000298023223876953125f * _18455);
                            }
                            else
                            {
                                _18476 = _18469;
                            }
                            _21846 = _18476;
                            break;
                        } while(false);
                        if (_21846)
                        {
                            uint _18701_dummy_parameter;
                            _21856 = -(r_motion_tp1.Load(int3(int2(floor(_18399 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18701_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18728_dummy_parameter;
                        float2 _21855;
                        do
                        {
                            float _18750 = 1.0f - _18399.y;
                            float4 _18761 = mul(float4((float2(_18399.x, _18750) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18399 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18728_dummy_parameter))))), 0)).x, 1.0f), _14728);
                            float _18763 = _18761.w;
                            if (!(_18763 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21855 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18776 = ((_18761.xy / _18763.xx) + 1.0f.xx) * 0.5f;
                            _21855 = float2(_18776.x - _18399.x, _18750 - _18776.y);
                            break;
                        } while(false);
                        float2 _18414 = abs(_21855);
                        bool2 _18418 = any(bool2(_18414.x > 4.0f.xx.x, _18414.y > 4.0f.xx.y)).xx;
                        _21856 = float2(_18418.x ? 0.0f.xx.x : _21855.x, _18418.y ? 0.0f.xx.y : _21855.y);
                        break;
                    } while(false);
                    bool _18794 = all(bool2(_21839.x > 0.0f.xx.x, _21839.y > 0.0f.xx.y));
                    bool _18800;
                    if (_18794)
                    {
                        _18800 = all(bool2(_21839.x < 1.0f.xx.x, _21839.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18800 = _18794;
                    }
                    float _21868;
                    if (_18800)
                    {
                        _21868 = length(((_21839 + (_21856 * cbFI_Timestep)) - _5544) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21868 = 1000000000.0f;
                    }
                    uint _18827_dummy_parameter;
                    float _18851 = log((r_depth_tm1.Load(int3(int2(floor(_18399 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18827_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _17364 = _21868 < 0.3499999940395355224609375f;
                    bool _17366 = _21836 < 0.3499999940395355224609375f;
                    bool _17376;
                    if (_17364)
                    {
                        _17376 = (!_17366) || (_18851 > _21889);
                    }
                    else
                    {
                        _17376 = _17364;
                    }
                    bool _17389;
                    if (!_17376)
                    {
                        _17389 = ((!_17364) && (!_17366)) && (_21868 < _21836);
                    }
                    else
                    {
                        _17389 = _17376;
                    }
                    _23777 = _17389 ? _18851 : _21889;
                    bool2 _23778 = _17389.xx;
                    _23779 = float2(_23778.x ? _21839.x : _21837.x, _23778.y ? _21839.y : _21837.y);
                    _23780 = _17389 ? _21868 : _21836;
                }
                float3 _18860 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21815, 0.0f).xyz;
                float3 _18868 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21837, 0.0f).xyz;
                uint _18875_dummy_parameter;
                uint _18906_dummy_parameter;
                float _14929 = exp((_21814 * (-2.0f)) * (_21814 * 2.0f));
                float _14936 = exp((_21836 * (-2.0f)) * (_21836 * 2.0f));
                float _14949 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21837, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18906_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21815, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18875_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14963 = ((_14929 * cbFI_Timestep) * ((1.0f - _14936) + ((_14936 * 2.0f) * _14949))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14973 = 1.0f - _14949;
                float _14980 = ((_14936 * _5769) * ((1.0f - _14929) + ((_14929 * 2.0f) * _14973))) + (9.9999997473787516355514526367188e-05f * _5769);
                float _14989 = (((_14929 * _14936) * 4.0f) * _14949) * _14973;
                float _15007 = (_14989 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18868 - _18860, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14989)) * max(_14929, _14936));
                if (_6917 == 30u)
                {
                    _21988 = _15007;
                    _21987 = _18860;
                    break;
                }
                if (_6917 == 31u)
                {
                    _21988 = _15007;
                    _21987 = _18868;
                    break;
                }
                if (_6917 == 32u)
                {
                    _21988 = _15007;
                    _21987 = float3(_14929, _14936, _14949);
                    break;
                }
                _21988 = _15007;
                _21987 = ((_18860 * _14963) + (_18868 * _14980)) / (_14963 + _14980).xxx;
                break;
            } while(false);
            _23475 = _21988;
            _23399 = _21987;
        }
        else
        {
            _23475 = 1.0f;
            _23399 = _23400;
        }
        uint _7247 = cbFI_pad0 & 255u;
        bool _23199;
        float3 _23398;
        if (_7247 != 0u)
        {
            float3 _7252 = r_present_backbuffer.Load(int3(_5045, 0)).xyz;
            float3 _7256 = r_current_interpolation_source.Load(int3(_5045, 0)).xyz;
            float3 _7260 = abs(_7252 - _7256);
            float3 _22004;
            if (_7247 == 2u)
            {
                _22004 = (abs(_7256) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _22004 = 0.000244140625f.xxx;
            }
            bool _7276 = any(bool3(_7260.x > _22004.x, _7260.y > _22004.y, _7260.z > _22004.z));
            bool3 _23781 = _7276.xxx;
            _23398 = float3(_23781.x ? _7252.x : _23399.x, _23781.y ? _7252.y : _23399.y, _23781.z ? _7252.z : _23399.z);
            _23199 = _7276;
        }
        else
        {
            _23398 = _23399;
            _23199 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18944;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18944);
        }
        float3 _23380;
        if (_6917 == 1u)
        {
            _23380 = lerp(_8749, _8757, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _23381;
            if (_6917 == 2u)
            {
                _23381 = lerp(_8765, _8773, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _23382;
                if (_6917 == 3u)
                {
                    _23382 = float(_23199).xxx;
                }
                else
                {
                    float3 _23383;
                    if (_6917 == 4u)
                    {
                        _23383 = float3(((_19884 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _23384;
                        if (_6917 == 5u)
                        {
                            _23384 = float3(((_8044 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _23385;
                            if (_6917 == 6u)
                            {
                                _23385 = float3(_21390.xy, _21390.z + _21390.w);
                            }
                            else
                            {
                                float3 _23386;
                                if (_6917 == 7u)
                                {
                                    _23386 = r_current_interpolation_source.Load(int3(_5045, 0)).xyz;
                                }
                                else
                                {
                                    float3 _23387;
                                    if (_6917 == 8u)
                                    {
                                        _23387 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5544, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _23388;
                                        if (_6921)
                                        {
                                            uint _18966_dummy_parameter;
                                            uint _18998_dummy_parameter;
                                            _23388 = float3(log((r_depth_tp1.Load(int3(int2(floor(_5544 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18966_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_5544 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18998_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _23389;
                                            if (_6924)
                                            {
                                                _23389 = _8765;
                                            }
                                            else
                                            {
                                                float3 _23390;
                                                if (_6917 == 20u)
                                                {
                                                    _23390 = _8749;
                                                }
                                                else
                                                {
                                                    float3 _23391;
                                                    if (_6917 == 21u)
                                                    {
                                                        _23391 = _8757;
                                                    }
                                                    else
                                                    {
                                                        float3 _23392;
                                                        if (_6917 == 22u)
                                                        {
                                                            _23392 = _8773;
                                                        }
                                                        else
                                                        {
                                                            float3 _23393;
                                                            if (_6917 == 18u)
                                                            {
                                                                _23393 = _22626;
                                                            }
                                                            else
                                                            {
                                                                float3 _23394;
                                                                if (_6917 == 19u)
                                                                {
                                                                    _23394 = _22316;
                                                                }
                                                                else
                                                                {
                                                                    float3 _23395;
                                                                    if (_6917 == 23u)
                                                                    {
                                                                        _23395 = _22012;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _23396;
                                                                        if (_6917 == 24u)
                                                                        {
                                                                            uint _7420 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7425 = float(rw_nfru_diagnostics.Load<uint>((_7420 + 35u) * 4 + 0));
                                                                            float _22005;
                                                                            if (_7425 > 0.0f)
                                                                            {
                                                                                _22005 = float(rw_nfru_diagnostics.Load<uint>((_7420 + 34u) * 4 + 0)) / _7425;
                                                                            }
                                                                            else
                                                                            {
                                                                                _22005 = 0.0f;
                                                                            }
                                                                            _23396 = float3(float(rw_nfru_diagnostics.Load<uint>((_7420 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7420 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _22005);
                                                                        }
                                                                        else
                                                                        {
                                                                            _23396 = _23398;
                                                                        }
                                                                        _23395 = _23396;
                                                                    }
                                                                    _23394 = _23395;
                                                                }
                                                                _23393 = _23394;
                                                            }
                                                            _23392 = _23393;
                                                        }
                                                        _23391 = _23392;
                                                    }
                                                    _23390 = _23391;
                                                }
                                                _23389 = _23390;
                                            }
                                            _23388 = _23389;
                                        }
                                        _23387 = _23388;
                                    }
                                    _23386 = _23387;
                                }
                                _23385 = _23386;
                            }
                            _23384 = _23385;
                        }
                        _23383 = _23384;
                    }
                    _23382 = _23383;
                }
                _23381 = _23382;
            }
            _23380 = _23381;
        }
        float3 _23379;
        if ((_6917 >= 9u) && (_6917 <= 11u))
        {
            uint _7485 = 64u + uint((_20107.y * cbFI_MvDepthLaneSize.x) + _20107.x);
            uint _7489 = rw_nfru_diagnostics.Load<uint>(_7485 * 4 + 0) & 15u;
            float3 _23413;
            if (_6917 == 10u)
            {
                float3 _23378;
                if ((rw_nfru_diagnostics.Load<uint>(_7485 * 4 + 0) & 32u) != 0u)
                {
                    _23378 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _23377;
                    if ((rw_nfru_diagnostics.Load<uint>(_7485 * 4 + 0) & 16u) != 0u)
                    {
                        _23377 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7510 = ((rw_nfru_diagnostics.Load<uint>(_7485 * 4 + 0) & 64u) != 0u).xxx;
                        _23377 = float3(_7510.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7510.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7510.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _23378 = _23377;
                }
                _23413 = _23378;
            }
            else
            {
                float3 _23414;
                if (_6917 == 11u)
                {
                    uint _7523 = (rw_nfru_diagnostics.Load<uint>(_7485 * 4 + 0) >> 8u) & 15u;
                    uint _7526 = (rw_nfru_diagnostics.Load<uint>(_7485 * 4 + 0) >> 12u) & 15u;
                    float3 _23370;
                    if ((_7489 == 2u) || (_7489 == 3u))
                    {
                        _23370 = _4745[_7489];
                    }
                    else
                    {
                        bool _7538 = _7523 == 3u;
                        bool _7540 = _7526 == 3u;
                        float3 _23371;
                        if (_7538 && _7540)
                        {
                            _23371 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _23372;
                            if (_7538)
                            {
                                _23372 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _23373;
                                if (_7540)
                                {
                                    _23373 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _23374;
                                    if ((_7523 == 4u) || (_7526 == 4u))
                                    {
                                        _23374 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _23375;
                                        if ((_7523 == 1u) || (_7526 == 1u))
                                        {
                                            _23375 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23783 = (_7489 == 1u).xxx;
                                            _23375 = float3(_23783.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23783.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23783.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _23374 = _23375;
                                    }
                                    _23373 = _23374;
                                }
                                _23372 = _23373;
                            }
                            _23371 = _23372;
                        }
                        _23370 = _23371;
                    }
                    _23414 = _23370;
                }
                else
                {
                    _23414 = _4745[min(_7489, 7u)];
                }
                _23413 = _23414;
            }
            _23379 = _23413;
        }
        else
        {
            _23379 = _23380;
        }
        float4 _23417;
        if ((_6917 >= 14u) && (_6917 <= 16u))
        {
            float2 _23415;
            if (_6917 == 14u)
            {
                uint _7596_dummy_parameter;
                uint _7602_dummy_parameter;
                _23415 = r_flow_tm1.Load(int3(clamp(int2(floor(_5544 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7596_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7602_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _23416;
                if (_6917 == 16u)
                {
                    uint _19074 = r_warped_flow_qdata_tm1.Load(int3(_5560, 0)).x & 2147483647u;
                    uint _19106 = uint(max((int((_19074 >> 16u) & 15u) - 6), 0));
                    _23416 = ((float2(float((1 - (2 * int((_19074 >> 15u) & 1u))) * int(((_19074 >> uint(7)) & 127u) << _19106)), float((1 - (2 * int((_19074 >> 14u) & 1u))) * int((_19074 & 127u) << _19106))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _23416 = _8044 * float2(cbFI_DisplaySize);
                }
                _23415 = _23416;
            }
            uint2 _7635 = uint2(clamp(round(_23415 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7637 = _7635.x;
            uint _7644 = _7635.y;
            _23417 = float4(float(_7637 & 255u), float((_7637 >> 8u) | ((_7644 & 15u) << 4u)), float(_7644 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _23418;
            if (_6917 == 17u)
            {
                _23418 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5560, 0)).x != 0u), _6004, 0.0f, 1.0f);
            }
            else
            {
                _23418 = float4(_23379, 1.0f);
            }
            _23417 = _23418;
        }
        rw_output[_5045] = _23417.xyz;
        if (_7227)
        {
            uint _19151 = uint((_5045.y * cbFI_DisplaySize.x) + _5045.x) * 2u;
            rw_nfru_select.Store<uint>(_19151 * 4 + 0, spvPackHalf2x16(_23417.xy));
            rw_nfru_select.Store<uint>((_19151 + 1u) * 4 + 0, spvPackHalf2x16(float2(_23417.z, (_23199 || (_6917 != 0u)) ? 2.0f : _23475)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7702 = ((uint(_5045.y) * uint(cbFI_DisplaySize.x)) + uint(_5045.x)) * 6u;
            uint _19177 = spvPackHalf2x16(clamp(_8748.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7702 * 4 + 0, (((_19177 & 32767u) >> 4u) | ((((_19177 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8748.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19212 = spvPackHalf2x16(clamp(_8756.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7702 + 1u) * 4 + 0, (((_19212 & 32767u) >> 4u) | ((((_19212 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8756.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19247 = spvPackHalf2x16(clamp(_8764.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7702 + 2u) * 4 + 0, (((_19247 & 32767u) >> 4u) | ((((_19247 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8764.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19282 = spvPackHalf2x16(clamp(_8772.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7702 + 3u) * 4 + 0, (((_19282 & 32767u) >> 4u) | ((((_19282 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8772.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19309 = r_current_interpolation_source.Load(int3(_5045, 0));
            uint _19323 = spvPackHalf2x16(clamp(_19309.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7702 + 4u) * 4 + 0, (((_19323 & 32767u) >> 4u) | ((((_19323 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19309.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _23494;
            if (_23199 || (_6917 != 0u))
            {
                _23494 = 4294967295u;
            }
            else
            {
                uint _19358 = spvPackHalf2x16(clamp(_23417.xy, 0.0f.xx, 65000.0f.xx));
                _23494 = (((_19358 & 32767u) >> 4u) | ((((_19358 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_23417.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7702 + 5u) * 4 + 0, _23494);
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
