static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19945;

static const int2 _1251[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1260[5] = { 2, 4, 7, 11, 16 };
static const float3 _4764[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _5081 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_5081.x >= cbFI_DisplaySize.x, _5081.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_5081] = float4(r_present_backbuffer.Load(int3(_5081, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_5081] = float4(r_current_interpolation_source.Load(int3(_5081, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7971 = cbFI_DisplaySize - int2(1, 1);
                int2 _7972 = clamp(_5081, int2(0, 0), _7971);
                uint _7982 = uint((_7972.y * cbFI_DisplaySize.x) + _7972.x) * 2u;
                uint _7985 = rw_nfru_select.Load<uint>(_7982 * 4 + 0);
                float2 _7986 = spvUnpackHalf2x16(_7985);
                uint _7990 = rw_nfru_select.Load<uint>((_7982 + 1u) * 4 + 0);
                float2 _7991 = spvUnpackHalf2x16(_7990);
                float _7992 = _7986.x;
                float _7994 = _7991.x;
                if (_7991.y > 1.5f)
                {
                    rw_output[_5081] = float4(_7992, _7986.y, _7994, 1.0f).xyz;
                    break;
                }
                int _23619;
                float _23620;
                float3 _23621;
                float _23622;
                float _23623;
                _23623 = 0.0f;
                _23622 = 0.0f;
                _23621 = 0.0f.xxx;
                _23620 = 0.0f;
                _23619 = -2;
                float3 _23626;
                float _23627;
                float _23628;
                float _23629;
                for (; _23619 <= 2; _23623 = _23629, _23622 = _23628, _23621 = _23626, _23620 = _23627, _23619++)
                {
                    _23629 = _23623;
                    _23628 = _23622;
                    _23627 = _23620;
                    _23626 = _23621;
                    for (int _23624 = -2; _23624 <= 2; )
                    {
                        float _7888 = float((_23624 * _23624) + (_23619 * _23619));
                        float _7893 = exp(_7888 * (-0.319999992847442626953125f));
                        int2 _7898 = int2(_23624, _23619);
                        int2 _8008 = clamp(_5081 + (_7898 * int2(2, 2)), int2(0, 0), _7971);
                        uint _8018 = uint((_8008.y * cbFI_DisplaySize.x) + _8008.x) * 2u;
                        float _7915 = exp(_7888 * (-0.5f));
                        int2 _8040 = clamp(_5081 + (_7898 * int2(6, 6)), int2(0, 0), _7971);
                        _23629 += _7915;
                        _23628 += (_7915 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_8040.y * cbFI_DisplaySize.x) + _8040.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23627 += _7893;
                        _23626 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_8018 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_8018 + 1u) * 4 + 0)).x, _19945).xyz * _7893);
                        _23624++;
                        continue;
                    }
                }
                float3 _7945 = _23621 / _23620.xxx;
                rw_output[_5081] = float4(_7945 + ((float4(_7992, _7986.y, _7994, _7991.y).xyz - _7945) * clamp(_23622 / _23623, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5593 = (float2(_5081) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5595 = float2(cbFI_MvDepthLaneSize);
        int2 _5604 = int2(floor(_5593 * _5595));
        int2 _5609 = int2(floor(_5593 * float2(cbFI_FlowLaneSize)));
        float4 _8111 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5593 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _8117 = r_warped_filled_flow_tm1.Load(int3(_5609, 0)).xy;
        float2 _8123 = r_warped_filled_motion_tp1.Load(int3(_5604, 0)).xy;
        bool _8145 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19946;
        if (_8145)
        {
            float _8158 = ((2.0f * _5593.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19946 = float2(atan(_8158) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5593.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_8158 * _8158))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19946 = _5593;
        }
        bool _5630 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19967;
        bool _20109;
        int2 _20190;
        float3 _22709;
        if (_5630)
        {
            float _19948;
            float _19950;
            _19950 = 2.0f;
            _19948 = -1.0f;
            uint _5180[9];
            float _23630;
            float _23633;
            for (int _19947 = 0; _19947 < 9; _19950 = _23633, _19948 = _23630, _19947++)
            {
                _5180[_19947] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5604 + int2((_19947 % 3) - 1, (_19947 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_5180[_19947] != 0u)
                {
                    float _23614;
                    if (_5180[_19947] == 0u)
                    {
                        _23614 = -1.0f;
                    }
                    else
                    {
                        _23614 = float((_5180[_19947] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23633 = min(_19950, _23614);
                    _23630 = max(_19948, _23614);
                }
                else
                {
                    _23633 = _19950;
                    _23630 = _19948;
                }
            }
            float _5676 = float(_19948 >= 0.0f);
            float3 _19483 = 0.0f.xxx;
            _19483.y = _5676;
            float2 _19968;
            bool _20110;
            int2 _20191;
            float3 _22710;
            if ((_19948 - _19950) > 0.0199999995529651641845703125f)
            {
                float _19956;
                int2 _19957;
                float2 _19958;
                int2 _19960;
                float2 _19966;
                _19966 = _8123;
                _19960 = _5604;
                _19958 = _8123;
                _19957 = _5604;
                _19956 = -1.0f;
                float _23638;
                int2 _23642;
                float2 _23653;
                int2 _23664;
                float2 _23697;
                float _23822;
                int _19955 = 0;
                float _23595 = 1000000000.0f;
                for (; _19955 < 9; _23595 = _23822, _19966 = _23697, _19960 = _23664, _19958 = _23653, _19957 = _23642, _19956 = _23638, _19955++)
                {
                    if (_5180[_19955] == 0u)
                    {
                        _23822 = _23595;
                        _23697 = _19966;
                        _23664 = _19960;
                        _23653 = _19958;
                        _23642 = _19957;
                        _23638 = _19956;
                        continue;
                    }
                    int2 _5711 = clamp(_5604 + int2((_19955 % 3) - 1, (_19955 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8233 = _5180[_19955] & 2147483647u;
                    uint _8265 = uint(max((int((_8233 >> 16u) & 15u) - 6), 0));
                    float2 _5717 = (float2(float((1 - (2 * int((_8233 >> 15u) & 1u))) * int(((_8233 >> uint(7)) & 127u) << _8265)), float((1 - (2 * int((_8233 >> 14u) & 1u))) * int((_8233 & 127u) << _8265))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23581;
                    if (_5180[_19955] == 0u)
                    {
                        _23581 = -1.0f;
                    }
                    else
                    {
                        _23581 = float((_5180[_19955] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5722 = _23581 - 0.100000001490116119384765625f;
                    float2 _23582;
                    if (_8145)
                    {
                        float2 _8342 = clamp((((_19946 + (_5717 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8345 = tan(_8342.x);
                        _23582 = (float2(_8345 / cbFI_DeviceToViewDepth.z, (tan(_8342.y) * sqrt(1.0f + (_8345 * _8345))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23582 = _19946 + (_5717 * cbFI_Timestep);
                    }
                    float _5729 = cbFI_Timestep - 1.0f;
                    float2 _23583;
                    if (_8145)
                    {
                        float2 _8413 = clamp((((_19946 + (_5717 * _5729)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8416 = tan(_8413.x);
                        _23583 = (float2(_8416 / cbFI_DeviceToViewDepth.z, (tan(_8413.y) * sqrt(1.0f + (_8416 * _8416))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23583 = _19946 + (_5717 * _5729);
                    }
                    bool _8449 = all(bool2(_23582.x > 0.0f.xx.x, _23582.y > 0.0f.xx.y));
                    bool _8455;
                    if (_8449)
                    {
                        _8455 = all(bool2(_23582.x < 1.0f.xx.x, _23582.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8455 = _8449;
                    }
                    float _23586;
                    if (_8455)
                    {
                        uint _8462_dummy_parameter;
                        _23586 = max((_5722 - (log((r_depth_tm1.Load(int3(int2(floor(_23582 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8462_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23586 = 0.0f;
                    }
                    bool _8492 = all(bool2(_23583.x > 0.0f.xx.x, _23583.y > 0.0f.xx.y));
                    bool _8498;
                    if (_8492)
                    {
                        _8498 = all(bool2(_23583.x < 1.0f.xx.x, _23583.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8498 = _8492;
                    }
                    float _23587;
                    if (_8498)
                    {
                        uint _8505_dummy_parameter;
                        _23587 = _23586 + max((_5722 - (log((r_depth_tp1.Load(int3(int2(floor(_23583 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8505_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23587 = _23586;
                    }
                    float _23639;
                    int2 _23643;
                    float2 _23654;
                    int2 _23665;
                    float2 _23698;
                    float _23823;
                    if (_23587 == 0.0f)
                    {
                        bool _5764 = _5722 > _19956;
                        bool2 _23831 = _5764.xx;
                        _23823 = _23595;
                        _23698 = float2(_23831.x ? _5717.x : _19966.x, _23831.y ? _5717.y : _19966.y);
                        _23665 = int2(_23831.x ? _5711.x : _19960.x, _23831.y ? _5711.y : _19960.y);
                        _23654 = _19958;
                        _23643 = _19957;
                        _23639 = _5764 ? _5722 : _19956;
                    }
                    else
                    {
                        bool _5773 = _23587 < _23595;
                        bool2 _23827 = _5773.xx;
                        _23823 = _5773 ? _23587 : _23595;
                        _23698 = _19966;
                        _23665 = _19960;
                        _23654 = float2(_23827.x ? _5717.x : _19958.x, _23827.y ? _5717.y : _19958.y);
                        _23643 = int2(_23827.x ? _5711.x : _19957.x, _23827.y ? _5711.y : _19957.y);
                        _23639 = _19956;
                    }
                    _23822 = _23823;
                    _23697 = _23698;
                    _23664 = _23665;
                    _23653 = _23654;
                    _23642 = _23643;
                    _23638 = _23639;
                }
                bool _5785 = _19956 < 0.0f;
                bool2 _23837 = _5785.xx;
                int2 _23840 = int2(_23837.x ? _19957.x : _19960.x, _23837.y ? _19957.y : _19960.y);
                _22710 = float3(1.0f, _5676, float(any(bool2(_23840.x != _5604.x, _23840.y != _5604.y))));
                _20191 = _23840;
                _20110 = _5785 ? false : true;
                _19968 = float2(_23837.x ? _19958.x : _19966.x, _23837.y ? _19958.y : _19966.y);
            }
            else
            {
                _22710 = _19483;
                _20191 = _5604;
                _20110 = false;
                _19968 = _8123;
            }
            _22709 = _22710;
            _20190 = _20191;
            _20109 = _20110;
            _19967 = _19968;
        }
        else
        {
            _22709 = 0.0f.xxx;
            _20190 = _5604;
            _20109 = false;
            _19967 = _8123;
        }
        float2 _19969;
        if (_8145)
        {
            float2 _8570 = clamp((((_19946 + (_19967 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8573 = tan(_8570.x);
            _19969 = (float2(_8573 / cbFI_DeviceToViewDepth.z, (tan(_8570.y) * sqrt(1.0f + (_8573 * _8573))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19969 = _19946 + (_19967 * cbFI_Timestep);
        }
        float _5808 = cbFI_Timestep - 1.0f;
        float2 _19971;
        if (_8145)
        {
            float2 _8641 = clamp((((_19946 + (_19967 * _5808)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8644 = tan(_8641.x);
            _19971 = (float2(_8644 / cbFI_DeviceToViewDepth.z, (tan(_8641.y) * sqrt(1.0f + (_8644 * _8644))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19971 = _19946 + (_19967 * _5808);
        }
        float _5813 = -cbFI_Timestep;
        float2 _19972;
        if (_8145)
        {
            float2 _8712 = clamp((((_19946 + (_8117 * _5813)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8715 = tan(_8712.x);
            _19972 = (float2(_8715 / cbFI_DeviceToViewDepth.z, (tan(_8712.y) * sqrt(1.0f + (_8715 * _8715))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19972 = _19946 + (_8117 * _5813);
        }
        float _5818 = 1.0f - cbFI_Timestep;
        float2 _19973;
        if (_8145)
        {
            float2 _8783 = clamp((((_19946 + (_8117 * _5818)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8786 = tan(_8783.x);
            _19973 = (float2(_8786 / cbFI_DeviceToViewDepth.z, (tan(_8783.y) * sqrt(1.0f + (_8786 * _8786))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19973 = _19946 + (_8117 * _5818);
        }
        float4 _8821 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19969, 0.0f);
        float3 _8822 = _8821.xyz;
        float4 _8829 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19971, 0.0f);
        float3 _8830 = _8829.xyz;
        float4 _8837 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19972, 0.0f);
        float3 _8838 = _8837.xyz;
        float4 _8845 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19973, 0.0f);
        float3 _8846 = _8845.xyz;
        float4 _8860 = exp(_8111 - max(max(max(_8111.x, _8111.y), _8111.z), _8111.w).xxxx);
        float4 _8867 = _8860 / (dot(_8860, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5834 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _20180;
        float _21488;
        if (_5834)
        {
            float2 _5840 = 0.5f.xx / _5595;
            float _5843 = _5840.x;
            float _5844 = -_5843;
            float _5846 = _5840.y;
            float _5847 = -_5846;
            float2 _5849 = _5593 + float2(_5844, _5847);
            float2 _5851 = float2(cbFI_DisplaySize);
            bool _19990;
            do
            {
                bool _8947 = all(bool2(_5849.x > 0.0f.xx.x, _5849.y > 0.0f.xx.y));
                bool _8953;
                if (_8947)
                {
                    _8953 = all(bool2(_5849.x < 1.0f.xx.x, _5849.y < 1.0f.xx.y));
                }
                else
                {
                    _8953 = _8947;
                }
                if (!_8953)
                {
                    _19990 = false;
                    break;
                }
                uint _8960_dummy_parameter;
                float4x4 _19988;
                do
                {
                    float4x4 _8974;
                    bool _19987;
                    do
                    {
                        _8974 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19987 = false;
                            break;
                        }
                        uint _9008 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9008 + 32u) * 4 + 0) != 1u)
                        {
                            _19987 = false;
                            break;
                        }
                        uint _19984;
                        _19984 = 0u;
                        for (; _19984 < 4u; _19984++)
                        {
                            for (uint _19985 = 0u; _19985 < 4u; )
                            {
                                _8974[_19984][_19985] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9008 + (_19984 * 4u)) + _19985) * 4 + 0));
                                _19985++;
                                continue;
                            }
                        }
                        _19987 = true;
                        break;
                    } while(false);
                    if (_19987)
                    {
                        _19988 = _8974;
                        break;
                    }
                    _19988 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19989;
                do
                {
                    float _9085 = _5849.x;
                    float _9088 = 1.0f - _5849.y;
                    float4 _9099 = mul(float4((float2(_9085, _9088) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5849 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8960_dummy_parameter))))), 0)).x, 1.0f), _19988);
                    float _9101 = _9099.w;
                    if (!(_9101 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19989 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9114 = ((_9099.xy / _9101.xx) + 1.0f.xx) * 0.5f;
                    _19989 = float2(_9114.x - _9085, _9088 - _9114.y);
                    break;
                } while(false);
                float2 _8911 = abs(_19989);
                if (any(bool2(_8911.x > 100000.0f.xx.x, _8911.y > 100000.0f.xx.y)))
                {
                    _19990 = false;
                    break;
                }
                float _8919 = length(_19989 * _5851);
                uint _9134_dummy_parameter;
                bool _8933 = _8919 > ((8.0f * _5851.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8940;
                if (_8933)
                {
                    _8940 = length((r_motion_tp1.Load(int3(int2(floor(_5849 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9134_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5851) < (0.20000000298023223876953125f * _8919);
                }
                else
                {
                    _8940 = _8933;
                }
                _19990 = _8940;
                break;
            } while(false);
            float2 _5861 = _5593 + float2(_5843, _5847);
            bool _19997;
            do
            {
                bool _9220 = all(bool2(_5861.x > 0.0f.xx.x, _5861.y > 0.0f.xx.y));
                bool _9226;
                if (_9220)
                {
                    _9226 = all(bool2(_5861.x < 1.0f.xx.x, _5861.y < 1.0f.xx.y));
                }
                else
                {
                    _9226 = _9220;
                }
                if (!_9226)
                {
                    _19997 = false;
                    break;
                }
                uint _9233_dummy_parameter;
                float4x4 _19995;
                do
                {
                    float4x4 _9247;
                    bool _19994;
                    do
                    {
                        _9247 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19994 = false;
                            break;
                        }
                        uint _9281 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9281 + 32u) * 4 + 0) != 1u)
                        {
                            _19994 = false;
                            break;
                        }
                        uint _19991;
                        _19991 = 0u;
                        for (; _19991 < 4u; _19991++)
                        {
                            for (uint _19992 = 0u; _19992 < 4u; )
                            {
                                _9247[_19991][_19992] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9281 + (_19991 * 4u)) + _19992) * 4 + 0));
                                _19992++;
                                continue;
                            }
                        }
                        _19994 = true;
                        break;
                    } while(false);
                    if (_19994)
                    {
                        _19995 = _9247;
                        break;
                    }
                    _19995 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19996;
                do
                {
                    float _9358 = _5861.x;
                    float _9361 = 1.0f - _5861.y;
                    float4 _9372 = mul(float4((float2(_9358, _9361) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5861 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9233_dummy_parameter))))), 0)).x, 1.0f), _19995);
                    float _9374 = _9372.w;
                    if (!(_9374 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19996 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9387 = ((_9372.xy / _9374.xx) + 1.0f.xx) * 0.5f;
                    _19996 = float2(_9387.x - _9358, _9361 - _9387.y);
                    break;
                } while(false);
                float2 _9184 = abs(_19996);
                if (any(bool2(_9184.x > 100000.0f.xx.x, _9184.y > 100000.0f.xx.y)))
                {
                    _19997 = false;
                    break;
                }
                float _9192 = length(_19996 * _5851);
                uint _9407_dummy_parameter;
                bool _9206 = _9192 > ((8.0f * _5851.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9213;
                if (_9206)
                {
                    _9213 = length((r_motion_tp1.Load(int3(int2(floor(_5861 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9407_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5851) < (0.20000000298023223876953125f * _9192);
                }
                else
                {
                    _9213 = _9206;
                }
                _19997 = _9213;
                break;
            } while(false);
            float2 _5874 = _5593 + float2(_5844, _5846);
            bool _20004;
            do
            {
                bool _9493 = all(bool2(_5874.x > 0.0f.xx.x, _5874.y > 0.0f.xx.y));
                bool _9499;
                if (_9493)
                {
                    _9499 = all(bool2(_5874.x < 1.0f.xx.x, _5874.y < 1.0f.xx.y));
                }
                else
                {
                    _9499 = _9493;
                }
                if (!_9499)
                {
                    _20004 = false;
                    break;
                }
                uint _9506_dummy_parameter;
                float4x4 _20002;
                do
                {
                    float4x4 _9520;
                    bool _20001;
                    do
                    {
                        _9520 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20001 = false;
                            break;
                        }
                        uint _9554 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9554 + 32u) * 4 + 0) != 1u)
                        {
                            _20001 = false;
                            break;
                        }
                        uint _19998;
                        _19998 = 0u;
                        for (; _19998 < 4u; _19998++)
                        {
                            for (uint _19999 = 0u; _19999 < 4u; )
                            {
                                _9520[_19998][_19999] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9554 + (_19998 * 4u)) + _19999) * 4 + 0));
                                _19999++;
                                continue;
                            }
                        }
                        _20001 = true;
                        break;
                    } while(false);
                    if (_20001)
                    {
                        _20002 = _9520;
                        break;
                    }
                    _20002 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _20003;
                do
                {
                    float _9631 = _5874.x;
                    float _9634 = 1.0f - _5874.y;
                    float4 _9645 = mul(float4((float2(_9631, _9634) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5874 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9506_dummy_parameter))))), 0)).x, 1.0f), _20002);
                    float _9647 = _9645.w;
                    if (!(_9647 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20003 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9660 = ((_9645.xy / _9647.xx) + 1.0f.xx) * 0.5f;
                    _20003 = float2(_9660.x - _9631, _9634 - _9660.y);
                    break;
                } while(false);
                float2 _9457 = abs(_20003);
                if (any(bool2(_9457.x > 100000.0f.xx.x, _9457.y > 100000.0f.xx.y)))
                {
                    _20004 = false;
                    break;
                }
                float _9465 = length(_20003 * _5851);
                uint _9680_dummy_parameter;
                bool _9479 = _9465 > ((8.0f * _5851.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9486;
                if (_9479)
                {
                    _9486 = length((r_motion_tp1.Load(int3(int2(floor(_5874 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9680_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5851) < (0.20000000298023223876953125f * _9465);
                }
                else
                {
                    _9486 = _9479;
                }
                _20004 = _9486;
                break;
            } while(false);
            float2 _5886 = _5593 + _5840;
            bool _20011;
            do
            {
                bool _9766 = all(bool2(_5886.x > 0.0f.xx.x, _5886.y > 0.0f.xx.y));
                bool _9772;
                if (_9766)
                {
                    _9772 = all(bool2(_5886.x < 1.0f.xx.x, _5886.y < 1.0f.xx.y));
                }
                else
                {
                    _9772 = _9766;
                }
                if (!_9772)
                {
                    _20011 = false;
                    break;
                }
                uint _9779_dummy_parameter;
                float4x4 _20009;
                do
                {
                    float4x4 _9793;
                    bool _20008;
                    do
                    {
                        _9793 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20008 = false;
                            break;
                        }
                        uint _9827 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9827 + 32u) * 4 + 0) != 1u)
                        {
                            _20008 = false;
                            break;
                        }
                        uint _20005;
                        _20005 = 0u;
                        for (; _20005 < 4u; _20005++)
                        {
                            for (uint _20006 = 0u; _20006 < 4u; )
                            {
                                _9793[_20005][_20006] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9827 + (_20005 * 4u)) + _20006) * 4 + 0));
                                _20006++;
                                continue;
                            }
                        }
                        _20008 = true;
                        break;
                    } while(false);
                    if (_20008)
                    {
                        _20009 = _9793;
                        break;
                    }
                    _20009 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _20010;
                do
                {
                    float _9904 = _5886.x;
                    float _9907 = 1.0f - _5886.y;
                    float4 _9918 = mul(float4((float2(_9904, _9907) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5886 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9779_dummy_parameter))))), 0)).x, 1.0f), _20009);
                    float _9920 = _9918.w;
                    if (!(_9920 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20010 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9933 = ((_9918.xy / _9920.xx) + 1.0f.xx) * 0.5f;
                    _20010 = float2(_9933.x - _9904, _9907 - _9933.y);
                    break;
                } while(false);
                float2 _9730 = abs(_20010);
                if (any(bool2(_9730.x > 100000.0f.xx.x, _9730.y > 100000.0f.xx.y)))
                {
                    _20011 = false;
                    break;
                }
                float _9738 = length(_20010 * _5851);
                uint _9953_dummy_parameter;
                bool _9752 = _9738 > ((8.0f * _5851.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9759;
                if (_9752)
                {
                    _9759 = length((r_motion_tp1.Load(int3(int2(floor(_5886 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9953_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5851) < (0.20000000298023223876953125f * _9738);
                }
                else
                {
                    _9759 = _9752;
                }
                _20011 = _9759;
                break;
            } while(false);
            float _5892 = 0.25f * (((float(_19990) + float(_19997)) + float(_20004)) + float(_20011));
            float4 _20181;
            if (_5892 < 1.0f)
            {
                bool _20018;
                do
                {
                    bool _10039 = all(bool2(_19969.x > 0.0f.xx.x, _19969.y > 0.0f.xx.y));
                    bool _10045;
                    if (_10039)
                    {
                        _10045 = all(bool2(_19969.x < 1.0f.xx.x, _19969.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10045 = _10039;
                    }
                    if (!_10045)
                    {
                        _20018 = false;
                        break;
                    }
                    uint _10052_dummy_parameter;
                    float4x4 _20016;
                    do
                    {
                        float4x4 _10066;
                        bool _20015;
                        do
                        {
                            _10066 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20015 = false;
                                break;
                            }
                            uint _10100 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10100 + 32u) * 4 + 0) != 1u)
                            {
                                _20015 = false;
                                break;
                            }
                            uint _20012;
                            _20012 = 0u;
                            for (; _20012 < 4u; _20012++)
                            {
                                for (uint _20013 = 0u; _20013 < 4u; )
                                {
                                    _10066[_20012][_20013] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10100 + (_20012 * 4u)) + _20013) * 4 + 0));
                                    _20013++;
                                    continue;
                                }
                            }
                            _20015 = true;
                            break;
                        } while(false);
                        if (_20015)
                        {
                            _20016 = _10066;
                            break;
                        }
                        _20016 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _20017;
                    do
                    {
                        float _10180 = 1.0f - _19969.y;
                        float4 _10191 = mul(float4((float2(_19969.x, _10180) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19969 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10052_dummy_parameter))))), 0)).x, 1.0f), _20016);
                        float _10193 = _10191.w;
                        if (!(_10193 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20017 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10206 = ((_10191.xy / _10193.xx) + 1.0f.xx) * 0.5f;
                        _20017 = float2(_10206.x - _19969.x, _10180 - _10206.y);
                        break;
                    } while(false);
                    float2 _10003 = abs(_20017);
                    if (any(bool2(_10003.x > 100000.0f.xx.x, _10003.y > 100000.0f.xx.y)))
                    {
                        _20018 = false;
                        break;
                    }
                    float _10011 = length(_20017 * _5851);
                    uint _10226_dummy_parameter;
                    bool _10025 = _10011 > ((8.0f * _5851.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10032;
                    if (_10025)
                    {
                        _10032 = length((r_motion_tp1.Load(int3(int2(floor(_19969 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10226_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5851) < (0.20000000298023223876953125f * _10011);
                    }
                    else
                    {
                        _10032 = _10025;
                    }
                    _20018 = _10032;
                    break;
                } while(false);
                bool _20025;
                do
                {
                    bool _10312 = all(bool2(_19971.x > 0.0f.xx.x, _19971.y > 0.0f.xx.y));
                    bool _10318;
                    if (_10312)
                    {
                        _10318 = all(bool2(_19971.x < 1.0f.xx.x, _19971.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10318 = _10312;
                    }
                    if (!_10318)
                    {
                        _20025 = false;
                        break;
                    }
                    uint _10325_dummy_parameter;
                    float4x4 _20023;
                    do
                    {
                        float4x4 _10339;
                        bool _20022;
                        do
                        {
                            _10339 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20022 = false;
                                break;
                            }
                            uint _10373 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10373 + 32u) * 4 + 0) != 1u)
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
                                    _10339[_20019][_20020] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10373 + (_20019 * 4u)) + _20020) * 4 + 0));
                                    _20020++;
                                    continue;
                                }
                            }
                            _20022 = true;
                            break;
                        } while(false);
                        if (_20022)
                        {
                            _20023 = _10339;
                            break;
                        }
                        _20023 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _20024;
                    do
                    {
                        float _10453 = 1.0f - _19971.y;
                        float4 _10464 = mul(float4((float2(_19971.x, _10453) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19971 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10325_dummy_parameter))))), 0)).x, 1.0f), _20023);
                        float _10466 = _10464.w;
                        if (!(_10466 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20024 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10479 = ((_10464.xy / _10466.xx) + 1.0f.xx) * 0.5f;
                        _20024 = float2(_10479.x - _19971.x, _10453 - _10479.y);
                        break;
                    } while(false);
                    float2 _10276 = abs(_20024);
                    if (any(bool2(_10276.x > 100000.0f.xx.x, _10276.y > 100000.0f.xx.y)))
                    {
                        _20025 = false;
                        break;
                    }
                    float _10284 = length(_20024 * _5851);
                    uint _10499_dummy_parameter;
                    bool _10298 = _10284 > ((8.0f * _5851.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10305;
                    if (_10298)
                    {
                        _10305 = length((r_motion_tp1.Load(int3(int2(floor(_19971 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10499_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5851) < (0.20000000298023223876953125f * _10284);
                    }
                    else
                    {
                        _10305 = _10298;
                    }
                    _20025 = _10305;
                    break;
                } while(false);
                bool _20032;
                do
                {
                    bool _10585 = all(bool2(_19972.x > 0.0f.xx.x, _19972.y > 0.0f.xx.y));
                    bool _10591;
                    if (_10585)
                    {
                        _10591 = all(bool2(_19972.x < 1.0f.xx.x, _19972.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10591 = _10585;
                    }
                    if (!_10591)
                    {
                        _20032 = false;
                        break;
                    }
                    uint _10598_dummy_parameter;
                    float4x4 _20030;
                    do
                    {
                        float4x4 _10612;
                        bool _20029;
                        do
                        {
                            _10612 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20029 = false;
                                break;
                            }
                            uint _10646 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10646 + 32u) * 4 + 0) != 1u)
                            {
                                _20029 = false;
                                break;
                            }
                            uint _20026;
                            _20026 = 0u;
                            for (; _20026 < 4u; _20026++)
                            {
                                for (uint _20027 = 0u; _20027 < 4u; )
                                {
                                    _10612[_20026][_20027] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10646 + (_20026 * 4u)) + _20027) * 4 + 0));
                                    _20027++;
                                    continue;
                                }
                            }
                            _20029 = true;
                            break;
                        } while(false);
                        if (_20029)
                        {
                            _20030 = _10612;
                            break;
                        }
                        _20030 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _20031;
                    do
                    {
                        float _10726 = 1.0f - _19972.y;
                        float4 _10737 = mul(float4((float2(_19972.x, _10726) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19972 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10598_dummy_parameter))))), 0)).x, 1.0f), _20030);
                        float _10739 = _10737.w;
                        if (!(_10739 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20031 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10752 = ((_10737.xy / _10739.xx) + 1.0f.xx) * 0.5f;
                        _20031 = float2(_10752.x - _19972.x, _10726 - _10752.y);
                        break;
                    } while(false);
                    float2 _10549 = abs(_20031);
                    if (any(bool2(_10549.x > 100000.0f.xx.x, _10549.y > 100000.0f.xx.y)))
                    {
                        _20032 = false;
                        break;
                    }
                    float _10557 = length(_20031 * _5851);
                    uint _10772_dummy_parameter;
                    bool _10571 = _10557 > ((8.0f * _5851.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10578;
                    if (_10571)
                    {
                        _10578 = length((r_motion_tp1.Load(int3(int2(floor(_19972 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10772_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5851) < (0.20000000298023223876953125f * _10557);
                    }
                    else
                    {
                        _10578 = _10571;
                    }
                    _20032 = _10578;
                    break;
                } while(false);
                bool _20039;
                do
                {
                    bool _10858 = all(bool2(_19973.x > 0.0f.xx.x, _19973.y > 0.0f.xx.y));
                    bool _10864;
                    if (_10858)
                    {
                        _10864 = all(bool2(_19973.x < 1.0f.xx.x, _19973.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10864 = _10858;
                    }
                    if (!_10864)
                    {
                        _20039 = false;
                        break;
                    }
                    uint _10871_dummy_parameter;
                    float4x4 _20037;
                    do
                    {
                        float4x4 _10885;
                        bool _20036;
                        do
                        {
                            _10885 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20036 = false;
                                break;
                            }
                            uint _10919 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10919 + 32u) * 4 + 0) != 1u)
                            {
                                _20036 = false;
                                break;
                            }
                            uint _20033;
                            _20033 = 0u;
                            for (; _20033 < 4u; _20033++)
                            {
                                for (uint _20034 = 0u; _20034 < 4u; )
                                {
                                    _10885[_20033][_20034] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10919 + (_20033 * 4u)) + _20034) * 4 + 0));
                                    _20034++;
                                    continue;
                                }
                            }
                            _20036 = true;
                            break;
                        } while(false);
                        if (_20036)
                        {
                            _20037 = _10885;
                            break;
                        }
                        _20037 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _20038;
                    do
                    {
                        float _10999 = 1.0f - _19973.y;
                        float4 _11010 = mul(float4((float2(_19973.x, _10999) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19973 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10871_dummy_parameter))))), 0)).x, 1.0f), _20037);
                        float _11012 = _11010.w;
                        if (!(_11012 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20038 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11025 = ((_11010.xy / _11012.xx) + 1.0f.xx) * 0.5f;
                        _20038 = float2(_11025.x - _19973.x, _10999 - _11025.y);
                        break;
                    } while(false);
                    float2 _10822 = abs(_20038);
                    if (any(bool2(_10822.x > 100000.0f.xx.x, _10822.y > 100000.0f.xx.y)))
                    {
                        _20039 = false;
                        break;
                    }
                    float _10830 = length(_20038 * _5851);
                    uint _11045_dummy_parameter;
                    bool _10844 = _10830 > ((8.0f * _5851.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10851;
                    if (_10844)
                    {
                        _10851 = length((r_motion_tp1.Load(int3(int2(floor(_19973 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _11045_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5851) < (0.20000000298023223876953125f * _10830);
                    }
                    else
                    {
                        _10851 = _10844;
                    }
                    _20039 = _10851;
                    break;
                } while(false);
                float4 _5919 = _8867 * float4(_20018 ? 0.0f : 1.0f, _20025 ? 0.0f : 1.0f, _20032 ? 0.0f : 1.0f, _20039 ? 0.0f : 1.0f);
                float _5921 = dot(_5919, 1.0f.xxxx);
                float4 _20182;
                if (_5921 > 0.001000000047497451305389404296875f)
                {
                    _20182 = _5919 / _5921.xxxx;
                }
                else
                {
                    _20182 = _8867;
                }
                _20181 = _20182;
            }
            else
            {
                _20181 = _8867;
            }
            _21488 = _5892;
            _20180 = _20181;
        }
        else
        {
            _21488 = 0.0f;
            _20180 = _8867;
        }
        bool _5938 = _5630 && (!_20109);
        bool _5947;
        if (_5938)
        {
            _5947 = (_20180.z + _20180.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5947 = _5938;
        }
        bool _5958;
        if (_5947)
        {
            _5958 = length((_19972 - _19969) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5958 = _5947;
        }
        bool _20269;
        if (_5958)
        {
            uint4 _11074 = r_warped_motion_qdata_tp1.Load(int3(_20190, 0));
            uint _11075 = _11074.x;
            bool _20272;
            if (_11075 != 0u)
            {
                float _20258;
                if (_11075 == 0u)
                {
                    _20258 = -1.0f;
                }
                else
                {
                    _20258 = float((_11075 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5968 = _20258 - 0.12000000476837158203125f;
                bool _11094 = all(bool2(_19972.x > 0.0f.xx.x, _19972.y > 0.0f.xx.y));
                bool _11100;
                if (_11094)
                {
                    _11100 = all(bool2(_19972.x < 1.0f.xx.x, _19972.y < 1.0f.xx.y));
                }
                else
                {
                    _11100 = _11094;
                }
                bool _5978;
                if (_11100)
                {
                    uint _11107_dummy_parameter;
                    _5978 = (log((r_depth_tm1.Load(int3(int2(floor(_19972 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11107_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5968;
                }
                else
                {
                    _5978 = _11100;
                }
                bool _5992;
                if (!_5978)
                {
                    bool _11137 = all(bool2(_19973.x > 0.0f.xx.x, _19973.y > 0.0f.xx.y));
                    bool _11143;
                    if (_11137)
                    {
                        _11143 = all(bool2(_19973.x < 1.0f.xx.x, _19973.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11143 = _11137;
                    }
                    bool _5990;
                    if (_11143)
                    {
                        uint _11150_dummy_parameter;
                        _5990 = (log((r_depth_tp1.Load(int3(int2(floor(_19973 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11150_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5968;
                    }
                    else
                    {
                        _5990 = _11143;
                    }
                    _5992 = _5990;
                }
                else
                {
                    _5992 = _5978;
                }
                _20272 = _5992;
            }
            else
            {
                _20272 = false;
            }
            _20269 = _20272;
        }
        else
        {
            _20269 = false;
        }
        bool _5997 = _20109 || _20269;
        bool _6002;
        if (_5997)
        {
            bool _11180 = all(bool2(_19969.x > 0.0f.xx.x, _19969.y > 0.0f.xx.y));
            bool _11186;
            if (_11180)
            {
                _11186 = all(bool2(_19969.x < 1.0f.xx.x, _19969.y < 1.0f.xx.y));
            }
            else
            {
                _11186 = _11180;
            }
            _6002 = _11186;
        }
        else
        {
            _6002 = _5997;
        }
        bool _6007;
        if (_6002)
        {
            bool _11191 = all(bool2(_19971.x > 0.0f.xx.x, _19971.y > 0.0f.xx.y));
            bool _11197;
            if (_11191)
            {
                _11197 = all(bool2(_19971.x < 1.0f.xx.x, _19971.y < 1.0f.xx.y));
            }
            else
            {
                _11197 = _11191;
            }
            _6007 = _11197;
        }
        else
        {
            _6007 = _6002;
        }
        float4 _20392;
        if (_6007)
        {
            float _6013 = _20180.x + _20180.y;
            float _6018 = _20180.z + _20180.w;
            float _20287;
            if (_6013 > 0.001000000047497451305389404296875f)
            {
                _20287 = _20180.x / _6013;
            }
            else
            {
                _20287 = _5818;
            }
            _20392 = float4(_20180.x + (_6018 * _20287), _20180.y + (_6018 * (1.0f - _20287)), 0.0f, 0.0f);
        }
        else
        {
            _20392 = _20180;
        }
        bool _11225 = (cbFI_pad0 & 1024u) != 0u;
        bool _11201 = !_11225;
        bool _11202 = !_11201;
        bool _11219;
        if (_11202)
        {
            _11219 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_20190.y * cbFI_MvDepthLaneSize.x) + _20190.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11219 = _11201;
        }
        bool _11251;
        if (_11202)
        {
            _11251 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5609.y * cbFI_FlowLaneSize.x) + _5609.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11251 = _11201;
        }
        float _6053 = float(_11251);
        bool _20413;
        float4 _20452;
        float3 _22399;
        if (_11225)
        {
            bool _6063;
            if (_11219)
            {
                _6063 = all(bool2(_19969.x > 0.0f.xx.x, _19969.y > 0.0f.xx.y));
            }
            else
            {
                _6063 = _11219;
            }
            bool _6069;
            if (_6063)
            {
                _6069 = all(bool2(_19969.x < 1.0f.xx.x, _19969.y < 1.0f.xx.y));
            }
            else
            {
                _6069 = _6063;
            }
            bool _6076;
            if (_11219)
            {
                _6076 = all(bool2(_19971.x > 0.0f.xx.x, _19971.y > 0.0f.xx.y));
            }
            else
            {
                _6076 = _11219;
            }
            bool _6082;
            if (_6076)
            {
                _6082 = all(bool2(_19971.x < 1.0f.xx.x, _19971.y < 1.0f.xx.y));
            }
            else
            {
                _6082 = _6076;
            }
            bool _6089;
            if (_11251)
            {
                _6089 = all(bool2(_19972.x > 0.0f.xx.x, _19972.y > 0.0f.xx.y));
            }
            else
            {
                _6089 = _11251;
            }
            bool _6095;
            if (_6089)
            {
                _6095 = all(bool2(_19972.x < 1.0f.xx.x, _19972.y < 1.0f.xx.y));
            }
            else
            {
                _6095 = _6089;
            }
            bool _6102;
            if (_11251)
            {
                _6102 = all(bool2(_19973.x > 0.0f.xx.x, _19973.y > 0.0f.xx.y));
            }
            else
            {
                _6102 = _11251;
            }
            bool _6108;
            if (_6102)
            {
                _6108 = all(bool2(_19973.x < 1.0f.xx.x, _19973.y < 1.0f.xx.y));
            }
            else
            {
                _6108 = _6102;
            }
            bool _6110 = !_11219;
            if (_6110)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11293;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11293);
                }
            }
            bool _6115 = !_11251;
            if (_6115)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11303;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11303);
                }
            }
            if (_11219 && _6115)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11313;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11313);
                }
            }
            if (_6110 && _11251)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11323;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11323);
                }
            }
            float _6134 = float(_6069);
            float _6136 = float(_6082);
            bool _6139 = _6095 && _6108;
            float _20321;
            if (_6139)
            {
                _20321 = 1.0f;
            }
            else
            {
                _20321 = (_6095 || _6108) ? 0.5f : 0.0f;
            }
            bool _20336;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_6069)) && (!_6082))
            {
                bool _6169;
                if (_6139)
                {
                    float _20329;
                    do
                    {
                        bool _11407 = all(bool2(_19972.x > 0.0f.xx.x, _19972.y > 0.0f.xx.y));
                        bool _11413;
                        if (_11407)
                        {
                            _11413 = all(bool2(_19972.x < 1.0f.xx.x, _19972.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11413 = _11407;
                        }
                        bool _11344 = !_11413;
                        bool _11351;
                        if (!_11344)
                        {
                            bool _11418 = all(bool2(_19973.x > 0.0f.xx.x, _19973.y > 0.0f.xx.y));
                            bool _11424;
                            if (_11418)
                            {
                                _11424 = all(bool2(_19973.x < 1.0f.xx.x, _19973.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11424 = _11418;
                            }
                            _11351 = !_11424;
                        }
                        else
                        {
                            _11351 = _11344;
                        }
                        if (_11351)
                        {
                            _20329 = 0.0f;
                            break;
                        }
                        uint _11431_dummy_parameter;
                        uint _11447_dummy_parameter;
                        float4x4 _20328;
                        do
                        {
                            float4x4 _11461;
                            bool _20327;
                            do
                            {
                                _11461 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20327 = false;
                                    break;
                                }
                                uint _11495 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11495 + 32u) * 4 + 0) != 1u)
                                {
                                    _20327 = false;
                                    break;
                                }
                                uint _20324;
                                _20324 = 0u;
                                for (; _20324 < 4u; _20324++)
                                {
                                    for (uint _20325 = 0u; _20325 < 4u; )
                                    {
                                        _11461[_20324][_20325] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11495 + 16u) + (_20324 * 4u)) + _20325) * 4 + 0));
                                        _20325++;
                                        continue;
                                    }
                                }
                                _20327 = true;
                                break;
                            } while(false);
                            if (_20327)
                            {
                                _20328 = _11461;
                                break;
                            }
                            _20328 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11372 = mul(float4((float2(_19972.x, 1.0f - _19972.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19972 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11431_dummy_parameter))))), 0)).x, 1.0f), _20328);
                        float _11374 = _11372.w;
                        if (abs(_11374) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20329 = 0.0f;
                            break;
                        }
                        float _11385 = abs(cbFI_DeviceToViewDepth.y / ((_11372.z / _11374) - cbFI_DeviceToViewDepth.x));
                        float _11388 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19973 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11447_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20329 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11385 - _11388) / max(max(_11385, _11388), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _6169 = _20329 >= 0.5f;
                }
                else
                {
                    _6169 = _6139;
                }
                bool _6177;
                if (_6169)
                {
                    _6177 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _6177 = _6169;
                }
                bool _20337;
                if (_6177)
                {
                    uint _11599_dummy_parameter;
                    float4x4 _20334;
                    do
                    {
                        float4x4 _11613;
                        bool _20333;
                        do
                        {
                            _11613 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20333 = false;
                                break;
                            }
                            uint _11647 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11647 + 32u) * 4 + 0) != 1u)
                            {
                                _20333 = false;
                                break;
                            }
                            uint _20330;
                            _20330 = 0u;
                            for (; _20330 < 4u; _20330++)
                            {
                                for (uint _20331 = 0u; _20331 < 4u; )
                                {
                                    _11613[_20330][_20331] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11647 + 16u) + (_20330 * 4u)) + _20331) * 4 + 0));
                                    _20331++;
                                    continue;
                                }
                            }
                            _20333 = true;
                            break;
                        } while(false);
                        if (_20333)
                        {
                            _20334 = _11613;
                            break;
                        }
                        _20334 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20335;
                    do
                    {
                        float _11727 = 1.0f - _19972.y;
                        float4 _11738 = mul(float4((float2(_19972.x, _11727) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19972 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11599_dummy_parameter))))), 0)).x, 1.0f), _20334);
                        float _11740 = _11738.w;
                        if (!(_11740 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20335 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11753 = ((_11738.xy / _11740.xx) + 1.0f.xx) * 0.5f;
                        _20335 = float2(_11753.x - _19972.x, _11727 - _11753.y);
                        break;
                    } while(false);
                    float2 _6190 = float2(cbFI_DisplaySize);
                    _20337 = length(((_19972 + _20335) - _19973) * _6190) <= ((0.100000001490116119384765625f * length(_20335 * _6190)) + 8.0f);
                }
                else
                {
                    _20337 = _6169;
                }
                _20336 = _20337;
            }
            else
            {
                _20336 = true;
            }
            bool _6204 = !_20336;
            bool _23841 = _6204 ? false : _6108;
            bool _23842 = _6204 ? false : _6095;
            bool _20414;
            float4 _20453;
            if (!(((_6069 && _6082) && _23842) && _23841))
            {
                float4 _6226 = _20392 * float4(_6134, _6136, float(_23842), float(_23841));
                float _6228 = dot(_6226, 1.0f.xxxx);
                bool _6231 = !(_6228 > 0.0f);
                float4 _20454;
                if (!_6231)
                {
                    _20454 = _6226 / _6228.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11775;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11775);
                    }
                    _20454 = 0.0f.xxxx;
                }
                _20453 = _20454;
                _20414 = _6231;
            }
            else
            {
                _20453 = _20392;
                _20414 = false;
            }
            _22399 = float3(_6134, _6136, _20321);
            _20452 = _20453;
            _20413 = _20414;
        }
        else
        {
            _22399 = float3(float(_11219), _6053, 0.0f);
            _20452 = _20392;
            _20413 = false;
        }
        bool _6249 = !_20413;
        float4 _20545;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6249)
        {
            float _6256 = _20452.x + _20452.y;
            float4 _20546;
            if (_6256 > 0.001000000047497451305389404296875f)
            {
                _20546 = float4(_20452.x / _6256, _20452.y / _6256, 0.0f, 0.0f);
            }
            else
            {
                _20546 = float4(_5818, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20545 = _20546;
        }
        else
        {
            _20545 = _20452;
        }
        float4 _20722;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6249) && _11219)
        {
            float _20519;
            do
            {
                uint4 _11915 = r_warped_motion_qdata_tp1.Load(int3(_20190, 0));
                uint _11916 = _11915.x;
                if (_11916 != 0u)
                {
                    float _20518;
                    if (_11916 == 0u)
                    {
                        _20518 = -1.0f;
                    }
                    else
                    {
                        _20518 = float((_11916 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20519 = _20518;
                    break;
                }
                int _20501;
                uint _20502;
                _20502 = _11916;
                _20501 = -1;
                uint _20517;
                for (; _20501 <= 1; _20502 = _20517, _20501++)
                {
                    _20517 = _20502;
                    for (int _20515 = -1; _20515 <= 1; )
                    {
                        _20517 = max(_20517, r_warped_motion_qdata_tp1.Load(int3(clamp(_20190 + int2(_20515, _20501), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20515++;
                        continue;
                    }
                }
                if (_20502 != 0u)
                {
                    float _20514;
                    if (_20502 == 0u)
                    {
                        _20514 = -1.0f;
                    }
                    else
                    {
                        _20514 = float((_20502 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20519 = _20514;
                    break;
                }
                uint _20504;
                _20504 = 4294967295u;
                uint _23734;
                for (int _20503 = 0; _20503 < 8; _20504 = _23734, _20503++)
                {
                    int _20507 = 0;
                    for (;;)
                    {
                        if (_20507 < 5)
                        {
                            int2 _11866 = _20190 + (_1251[_20503] * _1260[_20507].xx);
                            bool _11869 = any(bool2(_11866.x < int2(0, 0).x, _11866.y < int2(0, 0).y));
                            bool _11877;
                            if (!_11869)
                            {
                                _11877 = any(bool2(_11866.x >= cbFI_MvDepthLaneSize.x, _11866.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11877 = _11869;
                            }
                            if (_11877)
                            {
                                _23734 = _20504;
                                break;
                            }
                            uint4 _11955 = r_warped_motion_qdata_tp1.Load(int3(_11866, 0));
                            uint _11956 = _11955.x;
                            if (_11956 != 0u)
                            {
                                _23734 = min(_20504, _11956);
                                break;
                            }
                            _20507++;
                            continue;
                        }
                        else
                        {
                            _23734 = _20504;
                            break;
                        }
                    }
                }
                float _20506;
                if (_20504 == 4294967295u)
                {
                    _20506 = -1.0f;
                }
                else
                {
                    float _20505;
                    if (_20504 == 0u)
                    {
                        _20505 = -1.0f;
                    }
                    else
                    {
                        _20505 = float((_20504 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20506 = _20505;
                }
                _20519 = _20506;
                break;
            } while(false);
            float _6292 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6295 = r_warped_motion_qdata_tp1.Load(int3(_20190, 0)).x == 0u;
            bool _6301;
            if (_6295)
            {
                bool _11981 = all(bool2(_19969.x > 0.0f.xx.x, _19969.y > 0.0f.xx.y));
                bool _11987;
                if (_11981)
                {
                    _11987 = all(bool2(_19969.x < 1.0f.xx.x, _19969.y < 1.0f.xx.y));
                }
                else
                {
                    _11987 = _11981;
                }
                _6301 = _11987;
            }
            else
            {
                _6301 = _6295;
            }
            bool _6306;
            if (_6301)
            {
                bool _11992 = all(bool2(_19971.x > 0.0f.xx.x, _19971.y > 0.0f.xx.y));
                bool _11998;
                if (_11992)
                {
                    _11998 = all(bool2(_19971.x < 1.0f.xx.x, _19971.y < 1.0f.xx.y));
                }
                else
                {
                    _11998 = _11992;
                }
                _6306 = _11998;
            }
            else
            {
                _6306 = _6301;
            }
            bool _20531;
            float4 _20540;
            if (_6306)
            {
                uint _12005_dummy_parameter;
                float _12029 = log((r_depth_tm1.Load(int3(int2(floor(_19969 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12005_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _12037_dummy_parameter;
                float _12061 = log((r_depth_tp1.Load(int3(int2(floor(_19971 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12037_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _6317 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6324;
                if (_6317)
                {
                    _6324 = _12061 > (_12029 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6324 = _6317;
                }
                bool _20536;
                float4 _20558;
                if (_6324)
                {
                    _20558 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20536 = true;
                }
                else
                {
                    bool _6330 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6337;
                    if (_6330)
                    {
                        _6337 = _12029 > (_12061 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6337 = _6330;
                    }
                    bool4 _23843 = _6337.xxxx;
                    _20558 = float4(_23843.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20545.x, _23843.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20545.y, _23843.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20545.z, _23843.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20545.w);
                    _20536 = _6337 ? true : false;
                }
                _20540 = _20558;
                _20531 = _20536;
            }
            else
            {
                _20540 = _20545;
                _20531 = false;
            }
            float4 _20613;
            if (_20531)
            {
                _20613 = 1.0f.xxxx;
            }
            else
            {
                bool _6348 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6354;
                if (_6348)
                {
                    _6354 = _20540.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6354 = _6348;
                }
                bool _6359;
                if (_6354)
                {
                    bool _12067 = all(bool2(_19971.x > 0.0f.xx.x, _19971.y > 0.0f.xx.y));
                    bool _12073;
                    if (_12067)
                    {
                        _12073 = all(bool2(_19971.x < 1.0f.xx.x, _19971.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12073 = _12067;
                    }
                    _6359 = _12073;
                }
                else
                {
                    _6359 = _6354;
                }
                float4 _20614;
                if (_6359)
                {
                    float _20567;
                    if (_20519 >= 0.0f)
                    {
                        _20567 = _20519 - _6292;
                    }
                    else
                    {
                        float _20563;
                        _20563 = 2.0f;
                        float _12130;
                        for (int _20562 = 0; _20562 < 24; _20563 = _12130, _20562++)
                        {
                            float _12094 = float(_20562 & 7) * 0.785398185253143310546875f;
                            int _12096 = _20562 >> 3;
                            int _20564;
                            if (_12096 == 0)
                            {
                                _20564 = 16;
                            }
                            else
                            {
                                _20564 = (_12096 == 1) ? 48 : 96;
                            }
                            uint _12162_dummy_parameter;
                            _12130 = min(_20563, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19971 + ((cbFI_MvDepthLaneSizeRcp * float(_20564)) * float2(cos(_12094), sin(_12094))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12162_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20567 = _20563;
                    }
                    uint _12194_dummy_parameter;
                    float4 _20615;
                    if (r_depth_tp1.Load(int3(int2(floor(_19971 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12194_dummy_parameter))))), 0)).x > ((exp((_20567 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20615 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20615 = 1.0f.xxxx;
                    }
                    _20614 = _20615;
                }
                else
                {
                    _20614 = 1.0f.xxxx;
                }
                _20613 = _20614;
            }
            bool _6387 = _20519 >= 0.0f;
            bool _6388 = (!_20531) && _6387;
            bool _6395;
            if (_6388)
            {
                _6395 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6395 = _6388;
            }
            bool _6401;
            if (_6395)
            {
                _6401 = _20540.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6401 = _6395;
            }
            bool _6406;
            if (_6401)
            {
                bool _12218 = all(bool2(_19969.x > 0.0f.xx.x, _19969.y > 0.0f.xx.y));
                bool _12224;
                if (_12218)
                {
                    _12224 = all(bool2(_19969.x < 1.0f.xx.x, _19969.y < 1.0f.xx.y));
                }
                else
                {
                    _12224 = _12218;
                }
                _6406 = _12224;
            }
            else
            {
                _6406 = _6401;
            }
            float4 _20638;
            if (_6406)
            {
                float _20607;
                if (_6387)
                {
                    _20607 = _20519 - _6292;
                }
                else
                {
                    float _20603;
                    _20603 = 2.0f;
                    float _12281;
                    for (int _20602 = 0; _20602 < 24; _20603 = _12281, _20602++)
                    {
                        float _12245 = float(_20602 & 7) * 0.785398185253143310546875f;
                        int _12247 = _20602 >> 3;
                        int _20604;
                        if (_12247 == 0)
                        {
                            _20604 = 16;
                        }
                        else
                        {
                            _20604 = (_12247 == 1) ? 48 : 96;
                        }
                        uint _12297_dummy_parameter;
                        _12281 = min(_20603, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19969 + ((cbFI_MvDepthLaneSizeRcp * float(_20604)) * float2(cos(_12245), sin(_12245))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12297_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20607 = _20603;
                }
                uint _12345_dummy_parameter;
                float4 _20639;
                if (r_depth_tm1.Load(int3(int2(floor(_19969 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12345_dummy_parameter))))), 0)).x > ((exp((_20607 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19635 = _20613;
                    _19635.x = 0.0f;
                    _20639 = _19635;
                }
                else
                {
                    _20639 = _20613;
                }
                _20638 = _20639;
            }
            else
            {
                _20638 = _20613;
            }
            float4 _20651;
            if (_6388)
            {
                float _12371 = (exp(((_20519 - _6292) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6444 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6450;
                if (_6444)
                {
                    _6450 = _20540.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6450 = _6444;
                }
                bool _6455;
                if (_6450)
                {
                    bool _12376 = all(bool2(_19973.x > 0.0f.xx.x, _19973.y > 0.0f.xx.y));
                    bool _12382;
                    if (_12376)
                    {
                        _12382 = all(bool2(_19973.x < 1.0f.xx.x, _19973.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12382 = _12376;
                    }
                    _6455 = _12382;
                }
                else
                {
                    _6455 = _6450;
                }
                bool _6463;
                if (_6455)
                {
                    uint _12389_dummy_parameter;
                    _6463 = r_depth_tp1.Load(int3(int2(floor(_19973 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12389_dummy_parameter))))), 0)).x > _12371;
                }
                else
                {
                    _6463 = _6455;
                }
                float4 _20649;
                if (_6463)
                {
                    float4 _19638 = _20638;
                    _19638.w = 0.0f;
                    _20649 = _19638;
                }
                else
                {
                    _20649 = _20638;
                }
                bool _6470 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6476;
                if (_6470)
                {
                    _6476 = _20540.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6476 = _6470;
                }
                bool _6481;
                if (_6476)
                {
                    bool _12406 = all(bool2(_19972.x > 0.0f.xx.x, _19972.y > 0.0f.xx.y));
                    bool _12412;
                    if (_12406)
                    {
                        _12412 = all(bool2(_19972.x < 1.0f.xx.x, _19972.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12412 = _12406;
                    }
                    _6481 = _12412;
                }
                else
                {
                    _6481 = _6476;
                }
                bool _6489;
                if (_6481)
                {
                    uint _12419_dummy_parameter;
                    _6489 = r_depth_tm1.Load(int3(int2(floor(_19972 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12419_dummy_parameter))))), 0)).x > _12371;
                }
                else
                {
                    _6489 = _6481;
                }
                float4 _20652;
                if (_6489)
                {
                    float4 _19641 = _20649;
                    _19641.z = 0.0f;
                    _20652 = _19641;
                }
                else
                {
                    _20652 = _20649;
                }
                _20651 = _20652;
            }
            else
            {
                _20651 = _20638;
            }
            float4 _20723;
            if (any(bool4(_20651.x < 1.0f.xxxx.x, _20651.y < 1.0f.xxxx.y, _20651.z < 1.0f.xxxx.z, _20651.w < 1.0f.xxxx.w)))
            {
                float4 _6500 = _20540 * _20651;
                float _6502 = dot(_6500, 1.0f.xxxx);
                float4 _20724;
                if (_6502 > 0.0f)
                {
                    _20724 = _6500 / _6502.xxxx;
                }
                else
                {
                    bool _6513 = _20651.y == 0.0f;
                    bool _6519;
                    if (_6513)
                    {
                        _6519 = _20651.x > 0.0f;
                    }
                    else
                    {
                        _6519 = _6513;
                    }
                    bool _6524;
                    if (_6519)
                    {
                        bool _12436 = all(bool2(_19969.x > 0.0f.xx.x, _19969.y > 0.0f.xx.y));
                        bool _12442;
                        if (_12436)
                        {
                            _12442 = all(bool2(_19969.x < 1.0f.xx.x, _19969.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12442 = _12436;
                        }
                        _6524 = _12442;
                    }
                    else
                    {
                        _6524 = _6519;
                    }
                    float4 _20725;
                    if (_6524)
                    {
                        _20725 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6529 = _20651.x == 0.0f;
                        bool _6535;
                        if (_6529)
                        {
                            _6535 = _20651.y > 0.0f;
                        }
                        else
                        {
                            _6535 = _6529;
                        }
                        bool _6540;
                        if (_6535)
                        {
                            bool _12447 = all(bool2(_19971.x > 0.0f.xx.x, _19971.y > 0.0f.xx.y));
                            bool _12453;
                            if (_12447)
                            {
                                _12453 = all(bool2(_19971.x < 1.0f.xx.x, _19971.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12453 = _12447;
                            }
                            _6540 = _12453;
                        }
                        else
                        {
                            _6540 = _6535;
                        }
                        bool4 _23846 = _6540.xxxx;
                        _20725 = float4(_23846.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20540.x, _23846.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20540.y, _23846.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20540.z, _23846.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20540.w);
                    }
                    _20724 = _20725;
                }
                _20723 = _20724;
            }
            else
            {
                _20723 = _20540;
            }
            _20722 = _20723;
        }
        else
        {
            _20722 = _20545;
        }
        float4 _21452;
        bool _21758;
        float3 _22095;
        if (((cbFI_pad0 & 32768u) != 0u) && _6249)
        {
            bool _6557 = _20722.x > 0.00999999977648258209228515625f;
            bool _6560 = _20722.y > 0.00999999977648258209228515625f;
            bool _6569 = (_20722.z + _20722.w) > 0.0199999995529651641845703125f;
            bool _6575;
            if (_6569)
            {
                bool _12458 = all(bool2(_19972.x > 0.0f.xx.x, _19972.y > 0.0f.xx.y));
                bool _12464;
                if (_12458)
                {
                    _12464 = all(bool2(_19972.x < 1.0f.xx.x, _19972.y < 1.0f.xx.y));
                }
                else
                {
                    _12464 = _12458;
                }
                _6575 = _12464;
            }
            else
            {
                _6575 = _6569;
            }
            bool _6580;
            if (_6575)
            {
                bool _12469 = all(bool2(_19973.x > 0.0f.xx.x, _19973.y > 0.0f.xx.y));
                bool _12475;
                if (_12469)
                {
                    _12475 = all(bool2(_19973.x < 1.0f.xx.x, _19973.y < 1.0f.xx.y));
                }
                else
                {
                    _12475 = _12469;
                }
                _6580 = _12475;
            }
            else
            {
                _6580 = _6575;
            }
            bool _6587;
            if (_6580)
            {
                float _20738;
                do
                {
                    bool _12558 = all(bool2(_19972.x > 0.0f.xx.x, _19972.y > 0.0f.xx.y));
                    bool _12564;
                    if (_12558)
                    {
                        _12564 = all(bool2(_19972.x < 1.0f.xx.x, _19972.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12564 = _12558;
                    }
                    bool _12495 = !_12564;
                    bool _12502;
                    if (!_12495)
                    {
                        bool _12569 = all(bool2(_19973.x > 0.0f.xx.x, _19973.y > 0.0f.xx.y));
                        bool _12575;
                        if (_12569)
                        {
                            _12575 = all(bool2(_19973.x < 1.0f.xx.x, _19973.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12575 = _12569;
                        }
                        _12502 = !_12575;
                    }
                    else
                    {
                        _12502 = _12495;
                    }
                    if (_12502)
                    {
                        _20738 = 0.0f;
                        break;
                    }
                    uint _12582_dummy_parameter;
                    uint _12598_dummy_parameter;
                    float4x4 _20737;
                    do
                    {
                        float4x4 _12612;
                        bool _20736;
                        do
                        {
                            _12612 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20736 = false;
                                break;
                            }
                            uint _12646 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12646 + 32u) * 4 + 0) != 1u)
                            {
                                _20736 = false;
                                break;
                            }
                            uint _20733;
                            _20733 = 0u;
                            for (; _20733 < 4u; _20733++)
                            {
                                for (uint _20734 = 0u; _20734 < 4u; )
                                {
                                    _12612[_20733][_20734] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12646 + 16u) + (_20733 * 4u)) + _20734) * 4 + 0));
                                    _20734++;
                                    continue;
                                }
                            }
                            _20736 = true;
                            break;
                        } while(false);
                        if (_20736)
                        {
                            _20737 = _12612;
                            break;
                        }
                        _20737 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12523 = mul(float4((float2(_19972.x, 1.0f - _19972.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19972 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12582_dummy_parameter))))), 0)).x, 1.0f), _20737);
                    float _12525 = _12523.w;
                    if (abs(_12525) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20738 = 0.0f;
                        break;
                    }
                    float _12536 = abs(cbFI_DeviceToViewDepth.y / ((_12523.z / _12525) - cbFI_DeviceToViewDepth.x));
                    float _12539 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19973 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12598_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20738 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12536 - _12539) / max(max(_12536, _12539), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6587 = _20738 < 0.5f;
            }
            else
            {
                _6587 = _6580;
            }
            float4 _20757;
            if (_6587)
            {
                uint _12750_dummy_parameter;
                uint _12781_dummy_parameter;
                float4 _20758;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19972 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12750_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19973 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12781_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20758 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20758 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20757 = _20758;
            }
            else
            {
                _20757 = 1.0f.xxxx;
            }
            bool _6611;
            if (_11219)
            {
                bool _12810 = all(bool2(_19969.x > 0.0f.xx.x, _19969.y > 0.0f.xx.y));
                bool _12816;
                if (_12810)
                {
                    _12816 = all(bool2(_19969.x < 1.0f.xx.x, _19969.y < 1.0f.xx.y));
                }
                else
                {
                    _12816 = _12810;
                }
                _6611 = _12816;
            }
            else
            {
                _6611 = _11219;
            }
            bool _6617;
            if (_11219)
            {
                bool _12821 = all(bool2(_19971.x > 0.0f.xx.x, _19971.y > 0.0f.xx.y));
                bool _12827;
                if (_12821)
                {
                    _12827 = all(bool2(_19971.x < 1.0f.xx.x, _19971.y < 1.0f.xx.y));
                }
                else
                {
                    _12827 = _12821;
                }
                _6617 = _12827;
            }
            else
            {
                _6617 = _11219;
            }
            bool _6623;
            if (_11251)
            {
                bool _12832 = all(bool2(_19972.x > 0.0f.xx.x, _19972.y > 0.0f.xx.y));
                bool _12838;
                if (_12832)
                {
                    _12838 = all(bool2(_19972.x < 1.0f.xx.x, _19972.y < 1.0f.xx.y));
                }
                else
                {
                    _12838 = _12832;
                }
                _6623 = _12838;
            }
            else
            {
                _6623 = _11251;
            }
            bool _6629;
            if (_11251)
            {
                bool _12843 = all(bool2(_19973.x > 0.0f.xx.x, _19973.y > 0.0f.xx.y));
                bool _12849;
                if (_12843)
                {
                    _12849 = all(bool2(_19973.x < 1.0f.xx.x, _19973.y < 1.0f.xx.y));
                }
                else
                {
                    _12849 = _12843;
                }
                _6629 = _12849;
            }
            else
            {
                _6629 = _11251;
            }
            bool _6632 = _6623 != _6629;
            bool _6638;
            if (_6632)
            {
                _6638 = _6611 || _6617;
            }
            else
            {
                _6638 = _6632;
            }
            float4 _20860;
            if (_6638)
            {
                float4 _19668 = _20757;
                _19668.z = 0.0f;
                _19668.w = 0.0f;
                _20860 = _19668;
            }
            else
            {
                _20860 = _20757;
            }
            bool _6645 = _6611 && _6557;
            bool _6648 = _6617 && _6560;
            float4 _20965;
            float3 _22204;
            if (_6645 || _6648)
            {
                float _20855;
                do
                {
                    uint4 _12988 = r_warped_motion_qdata_tp1.Load(int3(_20190, 0));
                    uint _12989 = _12988.x;
                    if (_12989 != 0u)
                    {
                        float _20854;
                        if (_12989 == 0u)
                        {
                            _20854 = -1.0f;
                        }
                        else
                        {
                            _20854 = float((_12989 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20855 = _20854;
                        break;
                    }
                    int _20837;
                    uint _20838;
                    _20838 = _12989;
                    _20837 = -1;
                    uint _20853;
                    for (; _20837 <= 1; _20838 = _20853, _20837++)
                    {
                        _20853 = _20838;
                        for (int _20851 = -1; _20851 <= 1; )
                        {
                            _20853 = max(_20853, r_warped_motion_qdata_tp1.Load(int3(clamp(_20190 + int2(_20851, _20837), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20851++;
                            continue;
                        }
                    }
                    if (_20838 != 0u)
                    {
                        float _20850;
                        if (_20838 == 0u)
                        {
                            _20850 = -1.0f;
                        }
                        else
                        {
                            _20850 = float((_20838 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20855 = _20850;
                        break;
                    }
                    uint _20840;
                    _20840 = 4294967295u;
                    uint _23735;
                    for (int _20839 = 0; _20839 < 8; _20840 = _23735, _20839++)
                    {
                        int _20843 = 0;
                        for (;;)
                        {
                            if (_20843 < 5)
                            {
                                int2 _12939 = _20190 + (_1251[_20839] * _1260[_20843].xx);
                                bool _12942 = any(bool2(_12939.x < int2(0, 0).x, _12939.y < int2(0, 0).y));
                                bool _12950;
                                if (!_12942)
                                {
                                    _12950 = any(bool2(_12939.x >= cbFI_MvDepthLaneSize.x, _12939.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12950 = _12942;
                                }
                                if (_12950)
                                {
                                    _23735 = _20840;
                                    break;
                                }
                                uint4 _13028 = r_warped_motion_qdata_tp1.Load(int3(_12939, 0));
                                uint _13029 = _13028.x;
                                if (_13029 != 0u)
                                {
                                    _23735 = min(_20840, _13029);
                                    break;
                                }
                                _20843++;
                                continue;
                            }
                            else
                            {
                                _23735 = _20840;
                                break;
                            }
                        }
                    }
                    float _20842;
                    if (_20840 == 4294967295u)
                    {
                        _20842 = -1.0f;
                    }
                    else
                    {
                        float _20841;
                        if (_20840 == 0u)
                        {
                            _20841 = -1.0f;
                        }
                        else
                        {
                            _20841 = float((_20840 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20842 = _20841;
                    }
                    _20855 = _20842;
                    break;
                } while(false);
                bool _6656 = _20855 < 0.0f;
                float _20856;
                if (_6656)
                {
                    _20856 = 0.0f;
                }
                else
                {
                    _20856 = _20855 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _13050_dummy_parameter;
                uint _13082_dummy_parameter;
                float4 _20893;
                if ((_6656 && _6645) && _6648)
                {
                    uint _13114_dummy_parameter;
                    float _13138 = log((r_depth_tm1.Load(int3(int2(floor(_19969 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13114_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _13146_dummy_parameter;
                    float _13170 = log((r_depth_tp1.Load(int3(int2(floor(_19971 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13146_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20894;
                    if (_13138 > (_13170 + 0.07999999821186065673828125f))
                    {
                        float4 _19672 = _20860;
                        _19672.x = 0.0f;
                        _20894 = _19672;
                    }
                    else
                    {
                        float4 _20895;
                        if (_13170 > (_13138 + 0.07999999821186065673828125f))
                        {
                            float4 _19674 = _20860;
                            _19674.y = 0.0f;
                            _20895 = _19674;
                        }
                        else
                        {
                            _20895 = _20860;
                        }
                        _20894 = _20895;
                    }
                    _20893 = _20894;
                }
                else
                {
                    _20893 = _20860;
                }
                float _6708 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6710 = _20855 >= 0.0f;
                float _20876;
                if (_6710)
                {
                    _20876 = _20855 - _6708;
                }
                else
                {
                    float _20872;
                    if (_6645)
                    {
                        float _20871;
                        _20871 = 2.0f;
                        float _13228;
                        for (int _20870 = 0; _20870 < 24; _20871 = _13228, _20870++)
                        {
                            float _13192 = float(_20870 & 7) * 0.785398185253143310546875f;
                            int _13194 = _20870 >> 3;
                            int _20873;
                            if (_13194 == 0)
                            {
                                _20873 = 16;
                            }
                            else
                            {
                                _20873 = (_13194 == 1) ? 48 : 96;
                            }
                            uint _13244_dummy_parameter;
                            _13228 = min(_20871, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19969 + ((cbFI_MvDepthLaneSizeRcp * float(_20873)) * float2(cos(_13192), sin(_13192))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13244_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20872 = _20871;
                    }
                    else
                    {
                        _20872 = 0.0f;
                    }
                    _20876 = _20872;
                }
                float _20883;
                if (_6710)
                {
                    _20883 = _20855 - _6708;
                }
                else
                {
                    float _20879;
                    if (_6648)
                    {
                        float _20878;
                        _20878 = 2.0f;
                        float _13342;
                        for (int _20877 = 0; _20877 < 24; _20878 = _13342, _20877++)
                        {
                            float _13306 = float(_20877 & 7) * 0.785398185253143310546875f;
                            int _13308 = _20877 >> 3;
                            int _20880;
                            if (_13308 == 0)
                            {
                                _20880 = 16;
                            }
                            else
                            {
                                _20880 = (_13308 == 1) ? 48 : 96;
                            }
                            uint _13374_dummy_parameter;
                            _13342 = min(_20878, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19971 + ((cbFI_MvDepthLaneSizeRcp * float(_20880)) * float2(cos(_13306), sin(_13306))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13374_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20879 = _20878;
                    }
                    else
                    {
                        _20879 = 0.0f;
                    }
                    _20883 = _20879;
                }
                float _20884;
                if (_6645)
                {
                    uint _13406_dummy_parameter;
                    _20884 = r_depth_tm1.Load(int3(int2(floor(_19969 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13406_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20884 = 0.0f;
                }
                float _20885;
                if (_6648)
                {
                    uint _13425_dummy_parameter;
                    _20885 = r_depth_tp1.Load(int3(int2(floor(_19971 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13425_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20885 = 0.0f;
                }
                bool _6765;
                if (_6645)
                {
                    _6765 = _20884 > ((exp((_20876 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6765 = _6645;
                }
                float4 _20901;
                if (_6765)
                {
                    float4 _19676 = _20893;
                    _19676.x = 0.0f;
                    _20901 = _19676;
                }
                else
                {
                    _20901 = _20893;
                }
                bool _6777;
                if (_6648)
                {
                    _6777 = _20885 > ((exp((_20883 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6777 = _6648;
                }
                float4 _20903;
                if (_6777)
                {
                    float4 _19678 = _20901;
                    _19678.y = 0.0f;
                    _20903 = _19678;
                }
                else
                {
                    _20903 = _20901;
                }
                float4 _20966;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6710)
                {
                    bool _6797;
                    if (_6645)
                    {
                        _6797 = _20884 < ((exp((_20876 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6797 = _6645;
                    }
                    float4 _20905;
                    if (_6797)
                    {
                        float4 _19680 = _20903;
                        _19680.x = 0.0f;
                        _20905 = _19680;
                    }
                    else
                    {
                        _20905 = _20903;
                    }
                    bool _6809;
                    if (_6648)
                    {
                        _6809 = _20885 < ((exp((_20883 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6809 = _6648;
                    }
                    float4 _20967;
                    if (_6809)
                    {
                        float4 _19682 = _20905;
                        _19682.y = 0.0f;
                        _20967 = _19682;
                    }
                    else
                    {
                        _20967 = _20905;
                    }
                    _20966 = _20967;
                }
                else
                {
                    _20966 = _20903;
                }
                _22204 = float3(_20856, log((r_depth_tm1.Load(int3(int2(floor(_19969 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13050_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_19971 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13082_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _20965 = _20966;
            }
            else
            {
                _22204 = float3(0.0f, 0.0f, 0.5f);
                _20965 = _20860;
            }
            bool _6820 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6569;
            bool _6826;
            if (_6820)
            {
                _6826 = _6623 || _6629;
            }
            else
            {
                _6826 = _6820;
            }
            float4 _21008;
            if (_6826)
            {
                float _20960;
                do
                {
                    uint4 _13604 = r_warped_motion_qdata_tp1.Load(int3(_20190, 0));
                    uint _13605 = _13604.x;
                    if (_13605 != 0u)
                    {
                        float _20959;
                        if (_13605 == 0u)
                        {
                            _20959 = -1.0f;
                        }
                        else
                        {
                            _20959 = float((_13605 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20960 = _20959;
                        break;
                    }
                    int _20942;
                    uint _20943;
                    _20943 = _13605;
                    _20942 = -1;
                    uint _20958;
                    for (; _20942 <= 1; _20943 = _20958, _20942++)
                    {
                        _20958 = _20943;
                        for (int _20956 = -1; _20956 <= 1; )
                        {
                            _20958 = max(_20958, r_warped_motion_qdata_tp1.Load(int3(clamp(_20190 + int2(_20956, _20942), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20956++;
                            continue;
                        }
                    }
                    if (_20943 != 0u)
                    {
                        float _20955;
                        if (_20943 == 0u)
                        {
                            _20955 = -1.0f;
                        }
                        else
                        {
                            _20955 = float((_20943 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20960 = _20955;
                        break;
                    }
                    uint _20945;
                    _20945 = 4294967295u;
                    uint _23736;
                    for (int _20944 = 0; _20944 < 8; _20945 = _23736, _20944++)
                    {
                        int _20948 = 0;
                        for (;;)
                        {
                            if (_20948 < 5)
                            {
                                int2 _13555 = _20190 + (_1251[_20944] * _1260[_20948].xx);
                                bool _13558 = any(bool2(_13555.x < int2(0, 0).x, _13555.y < int2(0, 0).y));
                                bool _13566;
                                if (!_13558)
                                {
                                    _13566 = any(bool2(_13555.x >= cbFI_MvDepthLaneSize.x, _13555.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13566 = _13558;
                                }
                                if (_13566)
                                {
                                    _23736 = _20945;
                                    break;
                                }
                                uint4 _13644 = r_warped_motion_qdata_tp1.Load(int3(_13555, 0));
                                uint _13645 = _13644.x;
                                if (_13645 != 0u)
                                {
                                    _23736 = min(_20945, _13645);
                                    break;
                                }
                                _20948++;
                                continue;
                            }
                            else
                            {
                                _23736 = _20945;
                                break;
                            }
                        }
                    }
                    float _20947;
                    if (_20945 == 4294967295u)
                    {
                        _20947 = -1.0f;
                    }
                    else
                    {
                        float _20946;
                        if (_20945 == 0u)
                        {
                            _20946 = -1.0f;
                        }
                        else
                        {
                            _20946 = float((_20945 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20947 = _20946;
                    }
                    _20960 = _20947;
                    break;
                } while(false);
                float4 _21009;
                if (_20960 >= 0.0f)
                {
                    float _13666 = (exp((_20960 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6845;
                    if (_6623)
                    {
                        uint _13673_dummy_parameter;
                        _6845 = r_depth_tm1.Load(int3(int2(floor(_19972 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13673_dummy_parameter))))), 0)).x > _13666;
                    }
                    else
                    {
                        _6845 = _6623;
                    }
                    float4 _20978;
                    if (_6845)
                    {
                        float4 _19684 = _20965;
                        _19684.z = 0.0f;
                        _20978 = _19684;
                    }
                    else
                    {
                        _20978 = _20965;
                    }
                    bool _6857;
                    if (_6629)
                    {
                        uint _13692_dummy_parameter;
                        _6857 = r_depth_tp1.Load(int3(int2(floor(_19973 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13692_dummy_parameter))))), 0)).x > _13666;
                    }
                    else
                    {
                        _6857 = _6629;
                    }
                    float4 _21010;
                    if (_6857)
                    {
                        float4 _19686 = _20978;
                        _19686.w = 0.0f;
                        _21010 = _19686;
                    }
                    else
                    {
                        _21010 = _20978;
                    }
                    _21009 = _21010;
                }
                else
                {
                    _21009 = _20965;
                }
                _21008 = _21009;
            }
            else
            {
                _21008 = _20965;
            }
            bool _6865 = _6611 != _6617;
            bool _6872;
            if (_6865)
            {
                _6872 = _6611 ? _6557 : _6560;
            }
            else
            {
                _6872 = _6865;
            }
            bool _6879;
            if (_6872)
            {
                _6879 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6879 = _6872;
            }
            float4 _21111;
            if (_6879)
            {
                bool2 _6884 = _6611.xx;
                float2 _6885 = float2(_6884.x ? _19969.x : _19971.x, _6884.y ? _19969.y : _19971.y);
                float _20992;
                if (_6611)
                {
                    uint _13711_dummy_parameter;
                    _20992 = r_depth_tm1.Load(int3(int2(floor(_6885 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13711_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13727_dummy_parameter;
                    _20992 = r_depth_tp1.Load(int3(int2(floor(_6885 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13727_dummy_parameter))))), 0)).x;
                }
                float4x4 _20999;
                if (_6611)
                {
                    float4x4 _20988;
                    do
                    {
                        float4x4 _13741;
                        bool _20987;
                        do
                        {
                            _13741 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20987 = false;
                                break;
                            }
                            uint _13775 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13775 + 32u) * 4 + 0) != 1u)
                            {
                                _20987 = false;
                                break;
                            }
                            uint _20984;
                            _20984 = 0u;
                            for (; _20984 < 4u; _20984++)
                            {
                                for (uint _20985 = 0u; _20985 < 4u; )
                                {
                                    _13741[_20984][_20985] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13775 + 16u) + (_20984 * 4u)) + _20985) * 4 + 0));
                                    _20985++;
                                    continue;
                                }
                            }
                            _20987 = true;
                            break;
                        } while(false);
                        if (_20987)
                        {
                            _20988 = _13741;
                            break;
                        }
                        _20988 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20999 = _20988;
                }
                else
                {
                    float4x4 _20983;
                    do
                    {
                        float4x4 _13847;
                        bool _20982;
                        do
                        {
                            _13847 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20982 = false;
                                break;
                            }
                            uint _13881 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13881 + 32u) * 4 + 0) != 1u)
                            {
                                _20982 = false;
                                break;
                            }
                            uint _20979;
                            _20979 = 0u;
                            for (; _20979 < 4u; _20979++)
                            {
                                for (uint _20980 = 0u; _20980 < 4u; )
                                {
                                    _13847[_20979][_20980] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13881 + (_20979 * 4u)) + _20980) * 4 + 0));
                                    _20980++;
                                    continue;
                                }
                            }
                            _20982 = true;
                            break;
                        } while(false);
                        if (_20982)
                        {
                            _20983 = _13847;
                            break;
                        }
                        _20983 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20999 = _20983;
                }
                float2 _21000;
                do
                {
                    float _13958 = _6885.x;
                    float _13961 = 1.0f - _6885.y;
                    float4 _13972 = mul(float4((float2(_13958, _13961) * 2.0f) - 1.0f.xx, _20992, 1.0f), _20999);
                    float _13974 = _13972.w;
                    if (!(_13974 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21000 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13987 = ((_13972.xy / _13974.xx) + 1.0f.xx) * 0.5f;
                    _21000 = float2(_13987.x - _13958, _13961 - _13987.y);
                    break;
                } while(false);
                float2 _6915 = float2(cbFI_DisplaySize);
                float4 _21112;
                if (!(length(((_6885 + _21000) - float2(_6884.x ? _19971.x : _19969.x, _6884.y ? _19971.y : _19969.y)) * _6915) <= ((0.100000001490116119384765625f * length(_21000 * _6915)) + 8.0f)))
                {
                    float4 _21113;
                    if (_6611)
                    {
                        float4 _19696 = _21008;
                        _19696.x = 0.0f;
                        _21113 = _19696;
                    }
                    else
                    {
                        float4 _19698 = _21008;
                        _19698.y = 0.0f;
                        _21113 = _19698;
                    }
                    _21112 = _21113;
                }
                else
                {
                    _21112 = _21008;
                }
                _21111 = _21112;
            }
            else
            {
                _21111 = _21008;
            }
            float4 _6940 = _20722 * _21111;
            float _6942 = dot(_6940, 1.0f.xxxx);
            float4 _21453;
            bool _21759;
            if (_6942 > 0.0f)
            {
                _21759 = _20413;
                _21453 = _6940 / _6942.xxxx;
            }
            else
            {
                bool _6953 = any(bool4(_21111.x < 1.0f.xxxx.x, _21111.y < 1.0f.xxxx.y, _21111.z < 1.0f.xxxx.z, _21111.w < 1.0f.xxxx.w));
                if (_6953)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14009;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _14009);
                    }
                }
                bool4 _23849 = _6953.xxxx;
                _21759 = _6953 ? true : _20413;
                _21453 = float4(_23849.x ? 0.0f.xxxx.x : _20722.x, _23849.y ? 0.0f.xxxx.y : _20722.y, _23849.z ? 0.0f.xxxx.z : _20722.z, _23849.w ? 0.0f.xxxx.w : _20722.w);
            }
            _22095 = _22204;
            _21758 = _21759;
            _21452 = _21453;
        }
        else
        {
            _22095 = float3(0.0f, 0.0f, 0.5f);
            _21758 = _20413;
            _21452 = _20722;
        }
        uint _6962 = (cbFI_pad0 >> 24u) & 31u;
        uint _6966 = (cbFI_pad0 >> 16u) & 255u;
        bool _6968 = _6962 != 0u;
        bool _6970 = _6966 == 12u;
        bool _6973 = _6966 == 13u;
        float4 _21473;
        if ((_6968 || _6970) || _6973)
        {
            float _21119;
            do
            {
                bool _14093 = all(bool2(_19972.x > 0.0f.xx.x, _19972.y > 0.0f.xx.y));
                bool _14099;
                if (_14093)
                {
                    _14099 = all(bool2(_19972.x < 1.0f.xx.x, _19972.y < 1.0f.xx.y));
                }
                else
                {
                    _14099 = _14093;
                }
                bool _14030 = !_14099;
                bool _14037;
                if (!_14030)
                {
                    bool _14104 = all(bool2(_19973.x > 0.0f.xx.x, _19973.y > 0.0f.xx.y));
                    bool _14110;
                    if (_14104)
                    {
                        _14110 = all(bool2(_19973.x < 1.0f.xx.x, _19973.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _14110 = _14104;
                    }
                    _14037 = !_14110;
                }
                else
                {
                    _14037 = _14030;
                }
                if (_14037)
                {
                    _21119 = 0.0f;
                    break;
                }
                uint _14117_dummy_parameter;
                uint _14133_dummy_parameter;
                float4x4 _21118;
                do
                {
                    float4x4 _14147;
                    bool _21117;
                    do
                    {
                        _14147 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _21117 = false;
                            break;
                        }
                        uint _14181 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14181 + 32u) * 4 + 0) != 1u)
                        {
                            _21117 = false;
                            break;
                        }
                        uint _21114;
                        _21114 = 0u;
                        for (; _21114 < 4u; _21114++)
                        {
                            for (uint _21115 = 0u; _21115 < 4u; )
                            {
                                _14147[_21114][_21115] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14181 + 16u) + (_21114 * 4u)) + _21115) * 4 + 0));
                                _21115++;
                                continue;
                            }
                        }
                        _21117 = true;
                        break;
                    } while(false);
                    if (_21117)
                    {
                        _21118 = _14147;
                        break;
                    }
                    _21118 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _14058 = mul(float4((float2(_19972.x, 1.0f - _19972.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19972 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14117_dummy_parameter))))), 0)).x, 1.0f), _21118);
                float _14060 = _14058.w;
                if (abs(_14060) < 9.9999999747524270787835121154785e-07f)
                {
                    _21119 = 0.0f;
                    break;
                }
                float _14071 = abs(cbFI_DeviceToViewDepth.y / ((_14058.z / _14060) - cbFI_DeviceToViewDepth.x));
                float _14074 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19973 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _14133_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _21119 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_14071 - _14074) / max(max(_14071, _14074), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14283 = all(bool2(_19973.x > 0.0f.xx.x, _19973.y > 0.0f.xx.y));
            bool _14289;
            if (_14283)
            {
                _14289 = all(bool2(_19973.x < 1.0f.xx.x, _19973.y < 1.0f.xx.y));
            }
            else
            {
                _14289 = _14283;
            }
            float _21120;
            if (_14289)
            {
                uint _14296_dummy_parameter;
                _21120 = length((_8117 + (r_motion_tp1.Load(int3(int2(floor(_19973 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14296_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _21120 = 1000000.0f;
            }
            float _21135;
            if ((_6962 & 1u) != 0u)
            {
                _21135 = _21119;
            }
            else
            {
                _21135 = 1.0f;
            }
            float _21136;
            if ((_6962 & 2u) != 0u)
            {
                _21136 = _21135 * (1.0f - smoothstep(2.0f, 8.0f, _21120));
            }
            else
            {
                _21136 = _21135;
            }
            float _21137;
            if ((_6962 & 4u) != 0u)
            {
                _21137 = _21136 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8838 - _8846) - length(_8822 - _8830))));
            }
            else
            {
                _21137 = _21136;
            }
            float _21467;
            if ((_6962 & 8u) != 0u)
            {
                _21467 = lerp(1.0f, _21137, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8822 - _8830)));
            }
            else
            {
                _21467 = _21137;
            }
            bool _7048 = (_6962 & 16u) != 0u;
            bool _7057;
            if (_7048)
            {
                _7057 = length(_19967 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _7057 = _7048;
            }
            float _23851 = _7057 ? 1.0f : _21467;
            bool _7063 = _6968 && _11219;
            bool _7068;
            if (_7063)
            {
                bool _14321 = all(bool2(_19969.x > 0.0f.xx.x, _19969.y > 0.0f.xx.y));
                bool _14327;
                if (_14321)
                {
                    _14327 = all(bool2(_19969.x < 1.0f.xx.x, _19969.y < 1.0f.xx.y));
                }
                else
                {
                    _14327 = _14321;
                }
                _7068 = _14327;
            }
            else
            {
                _7068 = _7063;
            }
            bool _7073;
            if (_7068)
            {
                bool _14332 = all(bool2(_19971.x > 0.0f.xx.x, _19971.y > 0.0f.xx.y));
                bool _14338;
                if (_14332)
                {
                    _14338 = all(bool2(_19971.x < 1.0f.xx.x, _19971.y < 1.0f.xx.y));
                }
                else
                {
                    _14338 = _14332;
                }
                _7073 = _14338;
            }
            else
            {
                _7073 = _7068;
            }
            float4 _21474;
            if (_7073)
            {
                float _7079 = _21452.x + _21452.y;
                float _7088 = (_21452.z + _21452.w) * (1.0f - _23851);
                float _21470;
                if (_7079 > 9.9999997473787516355514526367188e-06f)
                {
                    _21470 = _21452.x / _7079;
                }
                else
                {
                    _21470 = _5818;
                }
                _21474 = float4(_21452.x + (_7088 * _21470), _21452.y + (_7088 * (1.0f - _21470)), _21452.zw * _23851);
            }
            else
            {
                _21474 = _21452;
            }
            _21473 = _21474;
        }
        else
        {
            _21473 = _21452;
        }
        float3 _7149 = (((_8822 * _21473.x) + (_8830 * _21473.y)) + (_8838 * _21473.z)) + (_8846 * _21473.w);
        float3 _23484;
        if (_5834 && (_21488 > 0.0f))
        {
            uint _14345_dummy_parameter;
            float2 _14360 = r_motion_tp1.Load(int3(int2(floor(_5593 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14345_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21750;
            if (_8145)
            {
                float2 _14405 = clamp((((_19946 + (_14360 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14408 = tan(_14405.x);
                _21750 = (float2(_14408 / cbFI_DeviceToViewDepth.z, (tan(_14405.y) * sqrt(1.0f + (_14408 * _14408))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21750 = _19946 + (_14360 * cbFI_Timestep);
            }
            float2 _21751;
            if (_8145)
            {
                float2 _14484 = clamp((((_19946 + (_14360 * _5808)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14487 = tan(_14484.x);
                _21751 = (float2(_14487 / cbFI_DeviceToViewDepth.z, (tan(_14484.y) * sqrt(1.0f + (_14487 * _14487))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21751 = _19946 + (_14360 * _5808);
            }
            _23484 = lerp(_7149, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21750, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21751, 0.0f).xyz, cbFI_Timestep.xxx), _21488.xxx);
        }
        else
        {
            _23484 = _7149;
        }
        float3 _23483;
        if (_21758)
        {
            float3 _14529 = r_current_interpolation_source.Load(int3(_5081, 0)).xyz;
            float3 _23485;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11219)
            {
                uint _14536_dummy_parameter;
                float _21881;
                _21881 = r_depth_tm1.Load(int3(int2(floor(_19969 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14536_dummy_parameter))))), 0)).x;
                float _7230;
                for (int _21880 = 0; _21880 < 24; _21881 = _7230, _21880++)
                {
                    float _7202 = float(_21880 & 7) * 0.785398185253143310546875f;
                    int _7204 = _21880 >> 3;
                    int _23578;
                    if (_7204 == 0)
                    {
                        _23578 = 16;
                    }
                    else
                    {
                        _23578 = (_7204 == 1) ? 48 : 96;
                    }
                    uint _14556_dummy_parameter;
                    _7230 = min(_21881, r_depth_tm1.Load(int3(int2(floor(clamp(_19969 + ((cbFI_MvDepthLaneSizeRcp * float(_23578)) * float2(cos(_7202), sin(_7202))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14556_dummy_parameter))))), 0)).x);
                }
                float2 _21882;
                do
                {
                    float _14578 = 1.0f - _19969.y;
                    float4 _14589 = mul(float4((float2(_19969.x, _14578) * 2.0f) - 1.0f.xx, _21881, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14591 = _14589.w;
                    if (!(_14591 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21882 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14604 = ((_14589.xy / _14591.xx) + 1.0f.xx) * 0.5f;
                    _21882 = float2(_14604.x - _19969.x, _14578 - _14604.y);
                    break;
                } while(false);
                float2 _7241 = _19969 + _21882;
                bool _14622 = all(bool2(_7241.x > 0.0f.xx.x, _7241.y > 0.0f.xx.y));
                bool _14628;
                if (_14622)
                {
                    _14628 = all(bool2(_7241.x < 1.0f.xx.x, _7241.y < 1.0f.xx.y));
                }
                else
                {
                    _14628 = _14622;
                }
                float3 _23486;
                if (_14628)
                {
                    float _7247 = abs(cbFI_DeviceToViewDepth.y / (_21881 - cbFI_DeviceToViewDepth.x));
                    uint _14648_dummy_parameter;
                    int2 _14648 = int2(spvTextureSize(r_depth_m2, uint(0), _14648_dummy_parameter));
                    float _7251 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7241 * float2(_14648))), int2(0, 0), _14648 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _23491;
                    if (abs(_7251 - _7247) <= (0.20000000298023223876953125f * max(_7251, _7247)))
                    {
                        uint _14682_dummy_parameter;
                        int2 _14682 = int2(spvTextureSize(r_colour_m2, uint(0), _14682_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14705;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14705);
                        }
                        _23491 = r_colour_m2.Load(int3(clamp(int2(floor(_7241 * float2(_14682))), int2(0, 0), _14682 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14715;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14715);
                        }
                        _23491 = _14529;
                    }
                    _23486 = _23491;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14725;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14725);
                    }
                    _23486 = _14529;
                }
                _23485 = _23486;
            }
            else
            {
                _23485 = _14529;
            }
            _23483 = _23485;
        }
        else
        {
            _23483 = _23484;
        }
        bool _7276 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _23482;
        float _23558;
        if (_7276)
        {
            float2 _7280 = float2(cbFI_DisplaySize);
            float3 _22070;
            float _22071;
            do
            {
                bool _15141;
                float4x4 _21889;
                do
                {
                    float4x4 _15117;
                    bool _21888;
                    do
                    {
                        _15117 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _15141 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_15141)
                        {
                            _21888 = false;
                            break;
                        }
                        uint _15151 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_15151 + 32u) * 4 + 0) != 1u)
                        {
                            _21888 = false;
                            break;
                        }
                        uint _21885;
                        _21885 = 0u;
                        for (; _21885 < 4u; _21885++)
                        {
                            for (uint _21886 = 0u; _21886 < 4u; )
                            {
                                _15117[_21885][_21886] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15151 + (_21885 * 4u)) + _21886) * 4 + 0));
                                _21886++;
                                continue;
                            }
                        }
                        _21888 = true;
                        break;
                    } while(false);
                    if (_21888)
                    {
                        _21889 = _15117;
                        break;
                    }
                    _21889 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float4x4 _14729 = _21889;
                float4x4 _14801 = spvInverse(_21889);
                float4x4 _14730 = _14801;
                if (_6966 == 35u)
                {
                    int2 _14808 = int2(_5593 * _7280);
                    bool _14815 = _14808.y != (int(_7280.y) / 2);
                    bool _14822;
                    if (!_14815)
                    {
                        _14822 = _14808.x >= 80;
                    }
                    else
                    {
                        _14822 = _14815;
                    }
                    if (_14822)
                    {
                        _22071 = 2.0f;
                        _22070 = 0.0f.xxx;
                        break;
                    }
                    int _14826 = _14808.x;
                    int _14827 = _14826 / 2;
                    float _22064;
                    if (_14827 < 16)
                    {
                        _22064 = _14729[_14827 / 4][_14827 % 4];
                    }
                    else
                    {
                        float _22065;
                        if (_14827 < 32)
                        {
                            int _14842 = _14827 - 16;
                            _22065 = _14730[_14842 / 4][_14842 % 4];
                        }
                        else
                        {
                            float _22066;
                            if (_14827 < 36)
                            {
                                _22066 = cbFI_DeviceToViewDepth[_14827 - 32];
                            }
                            else
                            {
                                float _22067;
                                if (_14827 == 36)
                                {
                                    _22067 = float(cbFI_RenderSize.x);
                                }
                                else
                                {
                                    float _22068;
                                    if (_14827 == 37)
                                    {
                                        _22068 = float(cbFI_RenderSize.y);
                                    }
                                    else
                                    {
                                        _22068 = 0.0f;
                                    }
                                    _22067 = _22068;
                                }
                                _22066 = _22067;
                            }
                            _22065 = _22066;
                        }
                        _22064 = _22065;
                    }
                    uint _14877 = asuint(_22064);
                    uint _22069;
                    if ((_14826 & 1) == 0)
                    {
                        _22069 = _14877 >> 16u;
                    }
                    else
                    {
                        _22069 = _14877 & 65535u;
                    }
                    _22071 = 2.0f;
                    _22070 = float3(float(_22069 >> 8u) * 0.0039215688593685626983642578125f, float(_22069 & 255u) * 0.0039215688593685626983642578125f, 0.0f);
                    break;
                }
                bool _14901 = _6966 == 33u;
                if (_14901 || (_6966 == 34u))
                {
                    uint _15239_dummy_parameter;
                    float2 _15254 = r_motion_tp1.Load(int3(int2(floor(clamp(_5593, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15239_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
                    float2 _22056;
                    if (_14901)
                    {
                        uint _15266_dummy_parameter;
                        float2 _22055;
                        do
                        {
                            float _15285 = _5593.x;
                            float _15288 = 1.0f - _5593.y;
                            float4 _15299 = mul(float4((float2(_15285, _15288) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5593 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15266_dummy_parameter))))), 0)).x, 1.0f), _21889);
                            float _15301 = _15299.w;
                            if (!(_15301 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22055 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15314 = ((_15299.xy / _15301.xx) + 1.0f.xx) * 0.5f;
                            _22055 = float2(_15314.x - _15285, _15288 - _15314.y);
                            break;
                        } while(false);
                        _22056 = _22055 - _15254;
                    }
                    else
                    {
                        float2 _14921 = _5593 + _15254;
                        bool _15332 = all(bool2(_14921.x > 0.0f.xx.x, _14921.y > 0.0f.xx.y));
                        bool _15338;
                        if (_15332)
                        {
                            _15338 = all(bool2(_14921.x < 1.0f.xx.x, _14921.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15338 = _15332;
                        }
                        float2 _22054;
                        if (_15338)
                        {
                            uint _15345_dummy_parameter;
                            float2 _22053;
                            do
                            {
                                float _15364 = _14921.x;
                                float _15367 = 1.0f - _14921.y;
                                float4 _15378 = mul(float4((float2(_15364, _15367) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14921 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _15345_dummy_parameter))))), 0)).x, 1.0f), _14801);
                                float _15380 = _15378.w;
                                if (!(_15380 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22053 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _15393 = ((_15378.xy / _15380.xx) + 1.0f.xx) * 0.5f;
                                _22053 = float2(_15393.x - _15364, _15367 - _15393.y);
                                break;
                            } while(false);
                            _22054 = _22053 + _15254;
                        }
                        else
                        {
                            _22054 = 0.0f.xx;
                        }
                        _22056 = _22054;
                    }
                    bool _22063;
                    do
                    {
                        bool _15472 = all(bool2(_5593.x > 0.0f.xx.x, _5593.y > 0.0f.xx.y));
                        bool _15478;
                        if (_15472)
                        {
                            _15478 = all(bool2(_5593.x < 1.0f.xx.x, _5593.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15478 = _15472;
                        }
                        if (!_15478)
                        {
                            _22063 = false;
                            break;
                        }
                        uint _15485_dummy_parameter;
                        float4x4 _22061;
                        do
                        {
                            float4x4 _15499;
                            bool _22060;
                            do
                            {
                                _15499 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_15141)
                                {
                                    _22060 = false;
                                    break;
                                }
                                uint _15533 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_15533 + 32u) * 4 + 0) != 1u)
                                {
                                    _22060 = false;
                                    break;
                                }
                                uint _22057;
                                _22057 = 0u;
                                for (; _22057 < 4u; _22057++)
                                {
                                    for (uint _22058 = 0u; _22058 < 4u; )
                                    {
                                        _15499[_22057][_22058] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15533 + (_22057 * 4u)) + _22058) * 4 + 0));
                                        _22058++;
                                        continue;
                                    }
                                }
                                _22060 = true;
                                break;
                            } while(false);
                            if (_22060)
                            {
                                _22061 = _15499;
                                break;
                            }
                            _22061 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _22062;
                        do
                        {
                            float _15610 = _5593.x;
                            float _15613 = 1.0f - _5593.y;
                            float4 _15624 = mul(float4((float2(_15610, _15613) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5593 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15485_dummy_parameter))))), 0)).x, 1.0f), _22061);
                            float _15626 = _15624.w;
                            if (!(_15626 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22062 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15639 = ((_15624.xy / _15626.xx) + 1.0f.xx) * 0.5f;
                            _22062 = float2(_15639.x - _15610, _15613 - _15639.y);
                            break;
                        } while(false);
                        float2 _15436 = abs(_22062);
                        if (any(bool2(_15436.x > 100000.0f.xx.x, _15436.y > 100000.0f.xx.y)))
                        {
                            _22063 = false;
                            break;
                        }
                        float _15444 = length(_22062 * _7280);
                        uint _15659_dummy_parameter;
                        bool _15458 = _15444 > ((8.0f * _7280.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _15465;
                        if (_15458)
                        {
                            _15465 = length((r_motion_tp1.Load(int3(int2(floor(_5593 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15659_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7280) < (0.20000000298023223876953125f * _15444);
                        }
                        else
                        {
                            _15465 = _15458;
                        }
                        _22063 = _15465;
                        break;
                    } while(false);
                    _22071 = 2.0f;
                    _22070 = float3(clamp(length(_22056 * float2(cbFI_RenderSize)) * 0.25f, 0.0f, 1.0f), float(_22063), 0.0f);
                    break;
                }
                float _15693;
                float _15696;
                float4 _15706;
                float2 _21890;
                do
                {
                    _15693 = _5593.x;
                    _15696 = 1.0f - _5593.y;
                    _15706 = float4((float2(_15693, _15696) * 2.0f) - 1.0f.xx, 1.0000000116860974230803549289703e-07f, 1.0f);
                    float4 _15707 = mul(_15706, _21889);
                    float _15709 = _15707.w;
                    if (!(_15709 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21890 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15722 = ((_15707.xy / _15709.xx) + 1.0f.xx) * 0.5f;
                    _21890 = float2(_15722.x - _15693, _15696 - _15722.y);
                    break;
                } while(false);
                float2 _21891;
                do
                {
                    float4 _15759 = mul(_15706, _14801);
                    float _15761 = _15759.w;
                    if (!(_15761 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21891 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15774 = ((_15759.xy / _15761.xx) + 1.0f.xx) * 0.5f;
                    _21891 = float2(_15774.x - _15693, _15696 - _15774.y);
                    break;
                } while(false);
                float2 _14956 = abs(_21890);
                bool2 _23852 = any(bool2(_14956.x > 4.0f.xx.x, _14956.y > 4.0f.xx.y)).xx;
                float2 _14962 = abs(_21891);
                bool2 _23854 = any(bool2(_14962.x > 4.0f.xx.x, _14962.y > 4.0f.xx.y)).xx;
                float2 _15788[3];
                _15788[0] = _5593;
                float2 _15908 = clamp(_5593, 0.0f.xx, 1.0f.xx);
                uint _15916_dummy_parameter;
                _15788[1] = _5593 - ((r_motion_tp1.Load(int3(int2(floor(_15908 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15916_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5818);
                _15788[2] = _5593 - (float2(_23852.x ? 0.0f.xx.x : _21890.x, _23852.y ? 0.0f.xx.y : _21890.y) * _5818);
                float _21897;
                float2 _21898;
                _21898 = _5593;
                _21897 = 1000000000.0f;
                float _23856;
                float2 _23858;
                float _23859;
                int _21896 = 0;
                float _22045 = -1.0f;
                for (; _21896 < 3; _22045 = _23856, _21898 = _23858, _21897 = _23859, _21896++)
                {
                    float2 _22035;
                    _22035 = _15788[_21896];
                    for (int _22034 = 0; _22034 < 30; )
                    {
                        uint _16430_dummy_parameter;
                        _22035 += (((_5593 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_22035, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16430_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5818)) - _22035) * 0.699999988079071044921875f);
                        _22034++;
                        continue;
                    }
                    float2 _16860 = clamp(_22035, 0.0f.xx, 1.0f.xx);
                    uint _16868_dummy_parameter;
                    bool _17298 = all(bool2(_22035.x > 0.0f.xx.x, _22035.y > 0.0f.xx.y));
                    bool _17304;
                    if (_17298)
                    {
                        _17304 = all(bool2(_22035.x < 1.0f.xx.x, _22035.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17304 = _17298;
                    }
                    float _22037;
                    if (_17304)
                    {
                        _22037 = length(((_22035 + ((r_motion_tp1.Load(int3(int2(floor(_16860 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16868_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5818)) - _5593) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22037 = 1000000000.0f;
                    }
                    uint _17315_dummy_parameter;
                    float _17355 = log((r_depth_tp1.Load(int3(int2(floor(_16860 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17315_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15868 = _22037 < 0.3499999940395355224609375f;
                    bool _15870 = _21897 < 0.3499999940395355224609375f;
                    bool _15880;
                    if (_15868)
                    {
                        _15880 = (!_15870) || (_17355 > _22045);
                    }
                    else
                    {
                        _15880 = _15868;
                    }
                    bool _15893;
                    if (!_15880)
                    {
                        _15893 = ((!_15868) && (!_15870)) && (_22037 < _21897);
                    }
                    else
                    {
                        _15893 = _15880;
                    }
                    _23856 = _15893 ? _17355 : _22045;
                    bool2 _23857 = _15893.xx;
                    _23858 = float2(_23857.x ? _22035.x : _21898.x, _23857.y ? _22035.y : _21898.y);
                    _23859 = _15893 ? _22037 : _21897;
                }
                float2 _17357[3];
                _17357[0] = _5593;
                float2 _21917;
                do
                {
                    bool _21907;
                    do
                    {
                        bool _17604 = all(bool2(_15908.x > 0.0f.xx.x, _15908.y > 0.0f.xx.y));
                        bool _17610;
                        if (_17604)
                        {
                            _17610 = all(bool2(_15908.x < 1.0f.xx.x, _15908.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17610 = _17604;
                        }
                        if (!_17610)
                        {
                            _21907 = false;
                            break;
                        }
                        uint _17617_dummy_parameter;
                        float4x4 _21905;
                        do
                        {
                            float4x4 _17631;
                            bool _21904;
                            do
                            {
                                _17631 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_15141)
                                {
                                    _21904 = false;
                                    break;
                                }
                                uint _17665 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17665 + 32u) * 4 + 0) != 1u)
                                {
                                    _21904 = false;
                                    break;
                                }
                                uint _21901;
                                _21901 = 0u;
                                for (; _21901 < 4u; _21901++)
                                {
                                    for (uint _21902 = 0u; _21902 < 4u; )
                                    {
                                        _17631[_21901][_21902] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17665 + (_21901 * 4u)) + _21902) * 4 + 0));
                                        _21902++;
                                        continue;
                                    }
                                }
                                _21904 = true;
                                break;
                            } while(false);
                            if (_21904)
                            {
                                _21905 = _17631;
                                break;
                            }
                            _21905 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21906;
                        do
                        {
                            float _17742 = _15908.x;
                            float _17745 = 1.0f - _15908.y;
                            float4 _17756 = mul(float4((float2(_17742, _17745) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15908 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17617_dummy_parameter))))), 0)).x, 1.0f), _21905);
                            float _17758 = _17756.w;
                            if (!(_17758 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21906 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17771 = ((_17756.xy / _17758.xx) + 1.0f.xx) * 0.5f;
                            _21906 = float2(_17771.x - _17742, _17745 - _17771.y);
                            break;
                        } while(false);
                        float2 _17568 = abs(_21906);
                        if (any(bool2(_17568.x > 100000.0f.xx.x, _17568.y > 100000.0f.xx.y)))
                        {
                            _21907 = false;
                            break;
                        }
                        float _17576 = length(_21906 * _7280);
                        uint _17791_dummy_parameter;
                        bool _17590 = _17576 > ((8.0f * _7280.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17597;
                        if (_17590)
                        {
                            _17597 = length((r_motion_tp1.Load(int3(int2(floor(_15908 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17791_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7280) < (0.20000000298023223876953125f * _17576);
                        }
                        else
                        {
                            _17597 = _17590;
                        }
                        _21907 = _17597;
                        break;
                    } while(false);
                    if (_21907)
                    {
                        uint _17822_dummy_parameter;
                        _21917 = -(r_motion_tp1.Load(int3(int2(floor(_15908 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17822_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17849_dummy_parameter;
                    float2 _21916;
                    do
                    {
                        float _17868 = _15908.x;
                        float _17871 = 1.0f - _15908.y;
                        float4 _17882 = mul(float4((float2(_17868, _17871) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15908 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17849_dummy_parameter))))), 0)).x, 1.0f), _14801);
                        float _17884 = _17882.w;
                        if (!(_17884 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21916 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17897 = ((_17882.xy / _17884.xx) + 1.0f.xx) * 0.5f;
                        _21916 = float2(_17897.x - _17868, _17871 - _17897.y);
                        break;
                    } while(false);
                    float2 _17535 = abs(_21916);
                    bool2 _17539 = any(bool2(_17535.x > 4.0f.xx.x, _17535.y > 4.0f.xx.y)).xx;
                    _21917 = float2(_17539.x ? 0.0f.xx.x : _21916.x, _17539.y ? 0.0f.xx.y : _21916.y);
                    break;
                } while(false);
                _17357[1] = _5593 - (_21917 * cbFI_Timestep);
                _17357[2] = _5593 - (float2(_23854.x ? 0.0f.xx.x : _21891.x, _23854.y ? 0.0f.xx.y : _21891.y) * cbFI_Timestep);
                float _21919;
                float2 _21920;
                _21920 = _5593;
                _21919 = 1000000000.0f;
                float _23860;
                float2 _23862;
                float _23863;
                float4x4 _18145;
                float4x4 _18583;
                int _21918 = 0;
                float _21972 = -1.0f;
                for (; _21918 < 3; _21972 = _23860, _21920 = _23862, _21919 = _23863, _21918++)
                {
                    float2 _21922;
                    _21922 = _17357[_21918];
                    float2 _17954;
                    for (int _21921 = 0; _21921 < 30; _21922 = _17954, _21921++)
                    {
                        float2 _22013;
                        do
                        {
                            float2 _18034 = clamp(_21922, 0.0f.xx, 1.0f.xx);
                            bool _22003;
                            do
                            {
                                bool _18118 = all(bool2(_18034.x > 0.0f.xx.x, _18034.y > 0.0f.xx.y));
                                bool _18124;
                                if (_18118)
                                {
                                    _18124 = all(bool2(_18034.x < 1.0f.xx.x, _18034.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _18124 = _18118;
                                }
                                if (!_18124)
                                {
                                    _22003 = false;
                                    break;
                                }
                                uint _18131_dummy_parameter;
                                float4x4 _22001;
                                do
                                {
                                    bool _22000;
                                    do
                                    {
                                        _18145 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_15141)
                                        {
                                            _22000 = false;
                                            break;
                                        }
                                        uint _18179 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_18179 + 32u) * 4 + 0) != 1u)
                                        {
                                            _22000 = false;
                                            break;
                                        }
                                        uint _21997;
                                        _21997 = 0u;
                                        for (; _21997 < 4u; _21997++)
                                        {
                                            for (uint _21998 = 0u; _21998 < 4u; )
                                            {
                                                _18145[_21997][_21998] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18179 + (_21997 * 4u)) + _21998) * 4 + 0));
                                                _21998++;
                                                continue;
                                            }
                                        }
                                        _22000 = true;
                                        break;
                                    } while(false);
                                    if (_22000)
                                    {
                                        _22001 = _18145;
                                        break;
                                    }
                                    _22001 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _22002;
                                do
                                {
                                    float _18256 = _18034.x;
                                    float _18259 = 1.0f - _18034.y;
                                    float4 _18270 = mul(float4((float2(_18256, _18259) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18034 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18131_dummy_parameter))))), 0)).x, 1.0f), _22001);
                                    float _18272 = _18270.w;
                                    if (!(_18272 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _22002 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _18285 = ((_18270.xy / _18272.xx) + 1.0f.xx) * 0.5f;
                                    _22002 = float2(_18285.x - _18256, _18259 - _18285.y);
                                    break;
                                } while(false);
                                float2 _18082 = abs(_22002);
                                if (any(bool2(_18082.x > 100000.0f.xx.x, _18082.y > 100000.0f.xx.y)))
                                {
                                    _22003 = false;
                                    break;
                                }
                                float _18090 = length(_22002 * _7280);
                                uint _18305_dummy_parameter;
                                bool _18104 = _18090 > ((8.0f * _7280.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _18111;
                                if (_18104)
                                {
                                    _18111 = length((r_motion_tp1.Load(int3(int2(floor(_18034 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18305_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7280) < (0.20000000298023223876953125f * _18090);
                                }
                                else
                                {
                                    _18111 = _18104;
                                }
                                _22003 = _18111;
                                break;
                            } while(false);
                            if (_22003)
                            {
                                uint _18336_dummy_parameter;
                                _22013 = -(r_motion_tp1.Load(int3(int2(floor(_18034 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18336_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _18363_dummy_parameter;
                            float2 _22012;
                            do
                            {
                                float _18382 = _18034.x;
                                float _18385 = 1.0f - _18034.y;
                                float4 _18396 = mul(float4((float2(_18382, _18385) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18034 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18363_dummy_parameter))))), 0)).x, 1.0f), _14801);
                                float _18398 = _18396.w;
                                if (!(_18398 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22012 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18411 = ((_18396.xy / _18398.xx) + 1.0f.xx) * 0.5f;
                                _22012 = float2(_18411.x - _18382, _18385 - _18411.y);
                                break;
                            } while(false);
                            float2 _18049 = abs(_22012);
                            bool2 _18053 = any(bool2(_18049.x > 4.0f.xx.x, _18049.y > 4.0f.xx.y)).xx;
                            _22013 = float2(_18053.x ? 0.0f.xx.x : _22012.x, _18053.y ? 0.0f.xx.y : _22012.y);
                            break;
                        } while(false);
                        _17954 = _21922 + (((_5593 - (_22013 * cbFI_Timestep)) - _21922) * 0.699999988079071044921875f);
                    }
                    float2 _18472;
                    float2 _21939;
                    do
                    {
                        _18472 = clamp(_21922, 0.0f.xx, 1.0f.xx);
                        bool _21929;
                        do
                        {
                            bool _18556 = all(bool2(_18472.x > 0.0f.xx.x, _18472.y > 0.0f.xx.y));
                            bool _18562;
                            if (_18556)
                            {
                                _18562 = all(bool2(_18472.x < 1.0f.xx.x, _18472.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18562 = _18556;
                            }
                            if (!_18562)
                            {
                                _21929 = false;
                                break;
                            }
                            uint _18569_dummy_parameter;
                            float4x4 _21927;
                            do
                            {
                                bool _21926;
                                do
                                {
                                    _18583 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_15141)
                                    {
                                        _21926 = false;
                                        break;
                                    }
                                    uint _18617 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18617 + 32u) * 4 + 0) != 1u)
                                    {
                                        _21926 = false;
                                        break;
                                    }
                                    uint _21923;
                                    _21923 = 0u;
                                    for (; _21923 < 4u; _21923++)
                                    {
                                        for (uint _21924 = 0u; _21924 < 4u; )
                                        {
                                            _18583[_21923][_21924] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18617 + (_21923 * 4u)) + _21924) * 4 + 0));
                                            _21924++;
                                            continue;
                                        }
                                    }
                                    _21926 = true;
                                    break;
                                } while(false);
                                if (_21926)
                                {
                                    _21927 = _18583;
                                    break;
                                }
                                _21927 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _21928;
                            do
                            {
                                float _18697 = 1.0f - _18472.y;
                                float4 _18708 = mul(float4((float2(_18472.x, _18697) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18472 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18569_dummy_parameter))))), 0)).x, 1.0f), _21927);
                                float _18710 = _18708.w;
                                if (!(_18710 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21928 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18723 = ((_18708.xy / _18710.xx) + 1.0f.xx) * 0.5f;
                                _21928 = float2(_18723.x - _18472.x, _18697 - _18723.y);
                                break;
                            } while(false);
                            float2 _18520 = abs(_21928);
                            if (any(bool2(_18520.x > 100000.0f.xx.x, _18520.y > 100000.0f.xx.y)))
                            {
                                _21929 = false;
                                break;
                            }
                            float _18528 = length(_21928 * _7280);
                            uint _18743_dummy_parameter;
                            bool _18542 = _18528 > ((8.0f * _7280.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18549;
                            if (_18542)
                            {
                                _18549 = length((r_motion_tp1.Load(int3(int2(floor(_18472 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18743_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7280) < (0.20000000298023223876953125f * _18528);
                            }
                            else
                            {
                                _18549 = _18542;
                            }
                            _21929 = _18549;
                            break;
                        } while(false);
                        if (_21929)
                        {
                            uint _18774_dummy_parameter;
                            _21939 = -(r_motion_tp1.Load(int3(int2(floor(_18472 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18774_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18801_dummy_parameter;
                        float2 _21938;
                        do
                        {
                            float _18823 = 1.0f - _18472.y;
                            float4 _18834 = mul(float4((float2(_18472.x, _18823) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18472 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18801_dummy_parameter))))), 0)).x, 1.0f), _14801);
                            float _18836 = _18834.w;
                            if (!(_18836 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21938 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18849 = ((_18834.xy / _18836.xx) + 1.0f.xx) * 0.5f;
                            _21938 = float2(_18849.x - _18472.x, _18823 - _18849.y);
                            break;
                        } while(false);
                        float2 _18487 = abs(_21938);
                        bool2 _18491 = any(bool2(_18487.x > 4.0f.xx.x, _18487.y > 4.0f.xx.y)).xx;
                        _21939 = float2(_18491.x ? 0.0f.xx.x : _21938.x, _18491.y ? 0.0f.xx.y : _21938.y);
                        break;
                    } while(false);
                    bool _18867 = all(bool2(_21922.x > 0.0f.xx.x, _21922.y > 0.0f.xx.y));
                    bool _18873;
                    if (_18867)
                    {
                        _18873 = all(bool2(_21922.x < 1.0f.xx.x, _21922.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18873 = _18867;
                    }
                    float _21951;
                    if (_18873)
                    {
                        _21951 = length(((_21922 + (_21939 * cbFI_Timestep)) - _5593) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21951 = 1000000000.0f;
                    }
                    uint _18900_dummy_parameter;
                    float _18924 = log((r_depth_tm1.Load(int3(int2(floor(_18472 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18900_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _17437 = _21951 < 0.3499999940395355224609375f;
                    bool _17439 = _21919 < 0.3499999940395355224609375f;
                    bool _17449;
                    if (_17437)
                    {
                        _17449 = (!_17439) || (_18924 > _21972);
                    }
                    else
                    {
                        _17449 = _17437;
                    }
                    bool _17462;
                    if (!_17449)
                    {
                        _17462 = ((!_17437) && (!_17439)) && (_21951 < _21919);
                    }
                    else
                    {
                        _17462 = _17449;
                    }
                    _23860 = _17462 ? _18924 : _21972;
                    bool2 _23861 = _17462.xx;
                    _23862 = float2(_23861.x ? _21922.x : _21920.x, _23861.y ? _21922.y : _21920.y);
                    _23863 = _17462 ? _21951 : _21919;
                }
                float3 _18933 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21898, 0.0f).xyz;
                float3 _18941 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21920, 0.0f).xyz;
                uint _18948_dummy_parameter;
                uint _18979_dummy_parameter;
                float _15002 = exp((_21897 * (-2.0f)) * (_21897 * 2.0f));
                float _15009 = exp((_21919 * (-2.0f)) * (_21919 * 2.0f));
                float _15022 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21920, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18979_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21898, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18948_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _15036 = ((_15002 * cbFI_Timestep) * ((1.0f - _15009) + ((_15009 * 2.0f) * _15022))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _15046 = 1.0f - _15022;
                float _15053 = ((_15009 * _5818) * ((1.0f - _15002) + ((_15002 * 2.0f) * _15046))) + (9.9999997473787516355514526367188e-05f * _5818);
                float _15062 = (((_15002 * _15009) * 4.0f) * _15022) * _15046;
                float _15080 = (_15062 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18941 - _18933, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _15062)) * max(_15002, _15009));
                if (_6966 == 30u)
                {
                    _22071 = _15080;
                    _22070 = _18933;
                    break;
                }
                if (_6966 == 31u)
                {
                    _22071 = _15080;
                    _22070 = _18941;
                    break;
                }
                if (_6966 == 32u)
                {
                    _22071 = _15080;
                    _22070 = float3(_15002, _15009, _15022);
                    break;
                }
                _22071 = _15080;
                _22070 = ((_18933 * _15036) + (_18941 * _15053)) / (_15036 + _15053).xxx;
                break;
            } while(false);
            _23558 = _22071;
            _23482 = _22070;
        }
        else
        {
            _23558 = 1.0f;
            _23482 = _23483;
        }
        uint _7296 = cbFI_pad0 & 255u;
        bool _23282;
        float3 _23481;
        if (_7296 != 0u)
        {
            float3 _7301 = r_present_backbuffer.Load(int3(_5081, 0)).xyz;
            float3 _7305 = r_current_interpolation_source.Load(int3(_5081, 0)).xyz;
            float3 _7309 = abs(_7301 - _7305);
            float3 _22087;
            if (_7296 == 2u)
            {
                _22087 = (abs(_7305) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _22087 = 0.000244140625f.xxx;
            }
            bool _7325 = any(bool3(_7309.x > _22087.x, _7309.y > _22087.y, _7309.z > _22087.z));
            bool3 _23864 = _7325.xxx;
            _23481 = float3(_23864.x ? _7301.x : _23482.x, _23864.y ? _7301.y : _23482.y, _23864.z ? _7301.z : _23482.z);
            _23282 = _7325;
        }
        else
        {
            _23481 = _23482;
            _23282 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _19017;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _19017);
        }
        float3 _23463;
        if (_6966 == 1u)
        {
            _23463 = lerp(_8822, _8830, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _23464;
            if (_6966 == 2u)
            {
                _23464 = lerp(_8838, _8846, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _23465;
                if (_6966 == 3u)
                {
                    _23465 = float(_23282).xxx;
                }
                else
                {
                    float3 _23466;
                    if (_6966 == 4u)
                    {
                        _23466 = float3(((_19967 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _23467;
                        if (_6966 == 5u)
                        {
                            _23467 = float3(((_8117 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _23468;
                            if (_6966 == 6u)
                            {
                                _23468 = float3(_21473.xy, _21473.z + _21473.w);
                            }
                            else
                            {
                                float3 _23469;
                                if (_6966 == 7u)
                                {
                                    _23469 = r_current_interpolation_source.Load(int3(_5081, 0)).xyz;
                                }
                                else
                                {
                                    float3 _23470;
                                    if (_6966 == 8u)
                                    {
                                        _23470 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5593, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _23471;
                                        if (_6970)
                                        {
                                            uint _19039_dummy_parameter;
                                            uint _19071_dummy_parameter;
                                            _23471 = float3(log((r_depth_tp1.Load(int3(int2(floor(_5593 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _19039_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_5593 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _19071_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _23472;
                                            if (_6973)
                                            {
                                                _23472 = _8838;
                                            }
                                            else
                                            {
                                                float3 _23473;
                                                if (_6966 == 20u)
                                                {
                                                    _23473 = _8822;
                                                }
                                                else
                                                {
                                                    float3 _23474;
                                                    if (_6966 == 21u)
                                                    {
                                                        _23474 = _8830;
                                                    }
                                                    else
                                                    {
                                                        float3 _23475;
                                                        if (_6966 == 22u)
                                                        {
                                                            _23475 = _8846;
                                                        }
                                                        else
                                                        {
                                                            float3 _23476;
                                                            if (_6966 == 18u)
                                                            {
                                                                _23476 = _22709;
                                                            }
                                                            else
                                                            {
                                                                float3 _23477;
                                                                if (_6966 == 19u)
                                                                {
                                                                    _23477 = _22399;
                                                                }
                                                                else
                                                                {
                                                                    float3 _23478;
                                                                    if (_6966 == 23u)
                                                                    {
                                                                        _23478 = _22095;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _23479;
                                                                        if (_6966 == 24u)
                                                                        {
                                                                            uint _7469 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7474 = float(rw_nfru_diagnostics.Load<uint>((_7469 + 35u) * 4 + 0));
                                                                            float _22088;
                                                                            if (_7474 > 0.0f)
                                                                            {
                                                                                _22088 = float(rw_nfru_diagnostics.Load<uint>((_7469 + 34u) * 4 + 0)) / _7474;
                                                                            }
                                                                            else
                                                                            {
                                                                                _22088 = 0.0f;
                                                                            }
                                                                            _23479 = float3(float(rw_nfru_diagnostics.Load<uint>((_7469 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7469 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _22088);
                                                                        }
                                                                        else
                                                                        {
                                                                            _23479 = _23481;
                                                                        }
                                                                        _23478 = _23479;
                                                                    }
                                                                    _23477 = _23478;
                                                                }
                                                                _23476 = _23477;
                                                            }
                                                            _23475 = _23476;
                                                        }
                                                        _23474 = _23475;
                                                    }
                                                    _23473 = _23474;
                                                }
                                                _23472 = _23473;
                                            }
                                            _23471 = _23472;
                                        }
                                        _23470 = _23471;
                                    }
                                    _23469 = _23470;
                                }
                                _23468 = _23469;
                            }
                            _23467 = _23468;
                        }
                        _23466 = _23467;
                    }
                    _23465 = _23466;
                }
                _23464 = _23465;
            }
            _23463 = _23464;
        }
        float3 _23462;
        if ((_6966 >= 9u) && (_6966 <= 11u))
        {
            uint _7534 = 64u + uint((_20190.y * cbFI_MvDepthLaneSize.x) + _20190.x);
            uint _7538 = rw_nfru_diagnostics.Load<uint>(_7534 * 4 + 0) & 15u;
            float3 _23496;
            if (_6966 == 10u)
            {
                float3 _23461;
                if ((rw_nfru_diagnostics.Load<uint>(_7534 * 4 + 0) & 32u) != 0u)
                {
                    _23461 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _23460;
                    if ((rw_nfru_diagnostics.Load<uint>(_7534 * 4 + 0) & 16u) != 0u)
                    {
                        _23460 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7559 = ((rw_nfru_diagnostics.Load<uint>(_7534 * 4 + 0) & 64u) != 0u).xxx;
                        _23460 = float3(_7559.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7559.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7559.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _23461 = _23460;
                }
                _23496 = _23461;
            }
            else
            {
                float3 _23497;
                if (_6966 == 11u)
                {
                    uint _7572 = (rw_nfru_diagnostics.Load<uint>(_7534 * 4 + 0) >> 8u) & 15u;
                    uint _7575 = (rw_nfru_diagnostics.Load<uint>(_7534 * 4 + 0) >> 12u) & 15u;
                    float3 _23453;
                    if ((_7538 == 2u) || (_7538 == 3u))
                    {
                        _23453 = _4764[_7538];
                    }
                    else
                    {
                        bool _7587 = _7572 == 3u;
                        bool _7589 = _7575 == 3u;
                        float3 _23454;
                        if (_7587 && _7589)
                        {
                            _23454 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _23455;
                            if (_7587)
                            {
                                _23455 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _23456;
                                if (_7589)
                                {
                                    _23456 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _23457;
                                    if ((_7572 == 4u) || (_7575 == 4u))
                                    {
                                        _23457 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _23458;
                                        if ((_7572 == 1u) || (_7575 == 1u))
                                        {
                                            _23458 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23866 = (_7538 == 1u).xxx;
                                            _23458 = float3(_23866.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23866.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23866.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _23457 = _23458;
                                    }
                                    _23456 = _23457;
                                }
                                _23455 = _23456;
                            }
                            _23454 = _23455;
                        }
                        _23453 = _23454;
                    }
                    _23497 = _23453;
                }
                else
                {
                    _23497 = _4764[min(_7538, 7u)];
                }
                _23496 = _23497;
            }
            _23462 = _23496;
        }
        else
        {
            _23462 = _23463;
        }
        float4 _23500;
        if ((_6966 >= 14u) && (_6966 <= 16u))
        {
            float2 _23498;
            if (_6966 == 14u)
            {
                uint _7645_dummy_parameter;
                uint _7651_dummy_parameter;
                _23498 = r_flow_tm1.Load(int3(clamp(int2(floor(_5593 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7645_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7651_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _23499;
                if (_6966 == 16u)
                {
                    uint _19147 = r_warped_flow_qdata_tm1.Load(int3(_5609, 0)).x & 2147483647u;
                    uint _19179 = uint(max((int((_19147 >> 16u) & 15u) - 6), 0));
                    _23499 = ((float2(float((1 - (2 * int((_19147 >> 15u) & 1u))) * int(((_19147 >> uint(7)) & 127u) << _19179)), float((1 - (2 * int((_19147 >> 14u) & 1u))) * int((_19147 & 127u) << _19179))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _23499 = _8117 * float2(cbFI_DisplaySize);
                }
                _23498 = _23499;
            }
            uint2 _7684 = uint2(clamp(round(_23498 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7686 = _7684.x;
            uint _7693 = _7684.y;
            _23500 = float4(float(_7686 & 255u), float((_7686 >> 8u) | ((_7693 & 15u) << 4u)), float(_7693 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _23501;
            if (_6966 == 17u)
            {
                _23501 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5609, 0)).x != 0u), _6053, 0.0f, 1.0f);
            }
            else
            {
                _23501 = float4(_23462, 1.0f);
            }
            _23500 = _23501;
        }
        rw_output[_5081] = _23500.xyz;
        if (_7276)
        {
            uint _19224 = uint((_5081.y * cbFI_DisplaySize.x) + _5081.x) * 2u;
            rw_nfru_select.Store<uint>(_19224 * 4 + 0, spvPackHalf2x16(_23500.xy));
            rw_nfru_select.Store<uint>((_19224 + 1u) * 4 + 0, spvPackHalf2x16(float2(_23500.z, (_23282 || (_6966 != 0u)) ? 2.0f : _23558)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7751 = ((uint(_5081.y) * uint(cbFI_DisplaySize.x)) + uint(_5081.x)) * 6u;
            uint _19250 = spvPackHalf2x16(clamp(_8821.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7751 * 4 + 0, (((_19250 & 32767u) >> 4u) | ((((_19250 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8821.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19285 = spvPackHalf2x16(clamp(_8829.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7751 + 1u) * 4 + 0, (((_19285 & 32767u) >> 4u) | ((((_19285 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8829.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19320 = spvPackHalf2x16(clamp(_8837.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7751 + 2u) * 4 + 0, (((_19320 & 32767u) >> 4u) | ((((_19320 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8837.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19355 = spvPackHalf2x16(clamp(_8845.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7751 + 3u) * 4 + 0, (((_19355 & 32767u) >> 4u) | ((((_19355 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8845.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19382 = r_current_interpolation_source.Load(int3(_5081, 0));
            uint _19396 = spvPackHalf2x16(clamp(_19382.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7751 + 4u) * 4 + 0, (((_19396 & 32767u) >> 4u) | ((((_19396 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19382.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _23577;
            if (_23282 || (_6966 != 0u))
            {
                _23577 = 4294967295u;
            }
            else
            {
                uint _19431 = spvPackHalf2x16(clamp(_23500.xy, 0.0f.xx, 65000.0f.xx));
                _23577 = (((_19431 & 32767u) >> 4u) | ((((_19431 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_23500.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7751 + 5u) * 4 + 0, _23577);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_5081] = float4(r_current_interpolation_source.Load(int3(_5081, 0)).xyz, 1.0f).xyz;
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
