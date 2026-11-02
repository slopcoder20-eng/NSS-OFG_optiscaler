static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3271[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3558 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3558.x >= cbFI_DisplaySize.x, _3558.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3558] = float4(r_present_backbuffer.Load(int3(_3558, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3944 = (float2(_3558) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3955 = int2(floor(_3944 * float2(cbFI_MvDepthLaneSize)));
        int2 _3960 = int2(floor(_3944 * float2(cbFI_FlowLaneSize)));
        float4 _5836 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3944 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5842 = r_warped_filled_flow_tm1.Load(int3(_3960, 0)).xy;
        float2 _5848 = r_warped_filled_motion_tp1.Load(int3(_3955, 0)).xy;
        bool _5870 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9922;
        if (_5870)
        {
            float _5883 = ((2.0f * _3944.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9922 = float2(atan(_5883) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3944.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5883 * _5883))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9922 = _3944;
        }
        bool _3981 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9943;
        bool _9964;
        int2 _9975;
        float3 _11321;
        if (_3981)
        {
            float _9924;
            float _9926;
            _9926 = 2.0f;
            _9924 = -1.0f;
            uint _3620[9];
            float _11752;
            float _11755;
            for (int _9923 = 0; _9923 < 9; _9926 = _11755, _9924 = _11752, _9923++)
            {
                _3620[_9923] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3955 + int2((_9923 % 3) - 1, (_9923 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3620[_9923] != 0u)
                {
                    float _11747;
                    if (_3620[_9923] == 0u)
                    {
                        _11747 = -1.0f;
                    }
                    else
                    {
                        _11747 = float((_3620[_9923] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _11755 = min(_9926, _11747);
                    _11752 = max(_9924, _11747);
                }
                else
                {
                    _11755 = _9926;
                    _11752 = _9924;
                }
            }
            float _4027 = float(_9924 >= 0.0f);
            float3 _9723 = 0.0f.xxx;
            _9723.y = _4027;
            float2 _9944;
            bool _9965;
            int2 _9976;
            float3 _11322;
            if ((_9924 - _9926) > 0.0199999995529651641845703125f)
            {
                float _9932;
                int2 _9933;
                float2 _9934;
                int2 _9936;
                float2 _9942;
                _9942 = _5848;
                _9936 = _3955;
                _9934 = _5848;
                _9933 = _3955;
                _9932 = -1.0f;
                float _11760;
                int2 _11764;
                float2 _11775;
                int2 _11786;
                float2 _11819;
                float _11866;
                int _9931 = 0;
                float _11728 = 1000000000.0f;
                for (; _9931 < 9; _11728 = _11866, _9942 = _11819, _9936 = _11786, _9934 = _11775, _9933 = _11764, _9932 = _11760, _9931++)
                {
                    if (_3620[_9931] == 0u)
                    {
                        _11866 = _11728;
                        _11819 = _9942;
                        _11786 = _9936;
                        _11775 = _9934;
                        _11764 = _9933;
                        _11760 = _9932;
                        continue;
                    }
                    int2 _4062 = clamp(_3955 + int2((_9931 % 3) - 1, (_9931 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5958 = _3620[_9931] & 2147483647u;
                    uint _5990 = uint(max((int((_5958 >> 16u) & 15u) - 6), 0));
                    float2 _4068 = (float2(float((1 - (2 * int((_5958 >> 15u) & 1u))) * int(((_5958 >> uint(7)) & 127u) << _5990)), float((1 - (2 * int((_5958 >> 14u) & 1u))) * int((_5958 & 127u) << _5990))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _11714;
                    if (_3620[_9931] == 0u)
                    {
                        _11714 = -1.0f;
                    }
                    else
                    {
                        _11714 = float((_3620[_9931] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4073 = _11714 - 0.100000001490116119384765625f;
                    float2 _11715;
                    if (_5870)
                    {
                        float2 _6067 = clamp((((_9922 + (_4068 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6070 = tan(_6067.x);
                        _11715 = (float2(_6070 / cbFI_DeviceToViewDepth.z, (tan(_6067.y) * sqrt(1.0f + (_6070 * _6070))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11715 = _9922 + (_4068 * cbFI_Timestep);
                    }
                    float _4080 = cbFI_Timestep - 1.0f;
                    float2 _11716;
                    if (_5870)
                    {
                        float2 _6138 = clamp((((_9922 + (_4068 * _4080)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6141 = tan(_6138.x);
                        _11716 = (float2(_6141 / cbFI_DeviceToViewDepth.z, (tan(_6138.y) * sqrt(1.0f + (_6141 * _6141))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _11716 = _9922 + (_4068 * _4080);
                    }
                    bool _6174 = all(bool2(_11715.x > 0.0f.xx.x, _11715.y > 0.0f.xx.y));
                    bool _6180;
                    if (_6174)
                    {
                        _6180 = all(bool2(_11715.x < 1.0f.xx.x, _11715.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6180 = _6174;
                    }
                    float _11719;
                    if (_6180)
                    {
                        uint _6187_dummy_parameter;
                        _11719 = max((_4073 - (log(((r_depth_tm1.Load(int3(int2(floor(_11715 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6187_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11719 = 0.0f;
                    }
                    bool _6217 = all(bool2(_11716.x > 0.0f.xx.x, _11716.y > 0.0f.xx.y));
                    bool _6223;
                    if (_6217)
                    {
                        _6223 = all(bool2(_11716.x < 1.0f.xx.x, _11716.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6223 = _6217;
                    }
                    float _11720;
                    if (_6223)
                    {
                        uint _6230_dummy_parameter;
                        _11720 = _11719 + max((_4073 - (log(((r_depth_tp1.Load(int3(int2(floor(_11716 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6230_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _11720 = _11719;
                    }
                    float _11761;
                    int2 _11765;
                    float2 _11776;
                    int2 _11787;
                    float2 _11820;
                    float _11867;
                    if (_11720 == 0.0f)
                    {
                        bool _4115 = _4073 > _9932;
                        bool2 _11875 = _4115.xx;
                        _11867 = _11728;
                        _11820 = float2(_11875.x ? _4068.x : _9942.x, _11875.y ? _4068.y : _9942.y);
                        _11787 = int2(_11875.x ? _4062.x : _9936.x, _11875.y ? _4062.y : _9936.y);
                        _11776 = _9934;
                        _11765 = _9933;
                        _11761 = _4115 ? _4073 : _9932;
                    }
                    else
                    {
                        bool _4124 = _11720 < _11728;
                        bool2 _11871 = _4124.xx;
                        _11867 = _4124 ? _11720 : _11728;
                        _11820 = _9942;
                        _11787 = _9936;
                        _11776 = float2(_11871.x ? _4068.x : _9934.x, _11871.y ? _4068.y : _9934.y);
                        _11765 = int2(_11871.x ? _4062.x : _9933.x, _11871.y ? _4062.y : _9933.y);
                        _11761 = _9932;
                    }
                    _11866 = _11867;
                    _11819 = _11820;
                    _11786 = _11787;
                    _11775 = _11776;
                    _11764 = _11765;
                    _11760 = _11761;
                }
                bool _4136 = _9932 < 0.0f;
                bool2 _11881 = _4136.xx;
                int2 _11884 = int2(_11881.x ? _9933.x : _9936.x, _11881.y ? _9933.y : _9936.y);
                _11322 = float3(1.0f, _4027, float(any(bool2(_11884.x != _3955.x, _11884.y != _3955.y))));
                _9976 = _11884;
                _9965 = _4136 ? false : true;
                _9944 = float2(_11881.x ? _9934.x : _9942.x, _11881.y ? _9934.y : _9942.y);
            }
            else
            {
                _11322 = _9723;
                _9976 = _3955;
                _9965 = false;
                _9944 = _5848;
            }
            _11321 = _11322;
            _9975 = _9976;
            _9964 = _9965;
            _9943 = _9944;
        }
        else
        {
            _11321 = 0.0f.xxx;
            _9975 = _3955;
            _9964 = false;
            _9943 = _5848;
        }
        float2 _9945;
        if (_5870)
        {
            float2 _6295 = clamp((((_9922 + (_9943 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6298 = tan(_6295.x);
            _9945 = (float2(_6298 / cbFI_DeviceToViewDepth.z, (tan(_6295.y) * sqrt(1.0f + (_6298 * _6298))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9945 = _9922 + (_9943 * cbFI_Timestep);
        }
        float _4159 = cbFI_Timestep - 1.0f;
        float2 _9947;
        if (_5870)
        {
            float2 _6366 = clamp((((_9922 + (_9943 * _4159)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6369 = tan(_6366.x);
            _9947 = (float2(_6369 / cbFI_DeviceToViewDepth.z, (tan(_6366.y) * sqrt(1.0f + (_6369 * _6369))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9947 = _9922 + (_9943 * _4159);
        }
        float _4164 = -cbFI_Timestep;
        float2 _9948;
        if (_5870)
        {
            float2 _6437 = clamp((((_9922 + (_5842 * _4164)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6440 = tan(_6437.x);
            _9948 = (float2(_6440 / cbFI_DeviceToViewDepth.z, (tan(_6437.y) * sqrt(1.0f + (_6440 * _6440))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9948 = _9922 + (_5842 * _4164);
        }
        float _4169 = 1.0f - cbFI_Timestep;
        float2 _9949;
        if (_5870)
        {
            float2 _6508 = clamp((((_9922 + (_5842 * _4169)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6511 = tan(_6508.x);
            _9949 = (float2(_6511 / cbFI_DeviceToViewDepth.z, (tan(_6508.y) * sqrt(1.0f + (_6511 * _6511))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9949 = _9922 + (_5842 * _4169);
        }
        float4 _6546 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9945, 0.0f);
        float3 _6547 = _6546.xyz;
        float4 _6554 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9947, 0.0f);
        float3 _6555 = _6554.xyz;
        float4 _6562 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9948, 0.0f);
        float3 _6563 = _6562.xyz;
        float4 _6570 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9949, 0.0f);
        float3 _6571 = _6570.xyz;
        float4 _6585 = exp(_5836 - max(max(max(_5836.x, _5836.y), _5836.z), _5836.w).xxxx);
        float4 _6592 = _6585 / (dot(_6585, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4188 = _3981 && (!_9964);
        bool _4197;
        if (_4188)
        {
            _4197 = (_6592.z + _6592.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4197 = _4188;
        }
        bool _4208;
        if (_4197)
        {
            _4208 = length((_9948 - _9945) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4208 = _4197;
        }
        bool _9988;
        if (_4208)
        {
            uint4 _6611 = r_warped_motion_qdata_tp1.Load(int3(_9975, 0));
            uint _6612 = _6611.x;
            bool _9991;
            if (_6612 != 0u)
            {
                float _9977;
                if (_6612 == 0u)
                {
                    _9977 = -1.0f;
                }
                else
                {
                    _9977 = float((_6612 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4218 = _9977 - 0.12000000476837158203125f;
                bool _6631 = all(bool2(_9948.x > 0.0f.xx.x, _9948.y > 0.0f.xx.y));
                bool _6637;
                if (_6631)
                {
                    _6637 = all(bool2(_9948.x < 1.0f.xx.x, _9948.y < 1.0f.xx.y));
                }
                else
                {
                    _6637 = _6631;
                }
                bool _4228;
                if (_6637)
                {
                    uint _6644_dummy_parameter;
                    _4228 = (log(((r_depth_tm1.Load(int3(int2(floor(_9948 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6644_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4218;
                }
                else
                {
                    _4228 = _6637;
                }
                bool _4242;
                if (!_4228)
                {
                    bool _6674 = all(bool2(_9949.x > 0.0f.xx.x, _9949.y > 0.0f.xx.y));
                    bool _6680;
                    if (_6674)
                    {
                        _6680 = all(bool2(_9949.x < 1.0f.xx.x, _9949.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6680 = _6674;
                    }
                    bool _4240;
                    if (_6680)
                    {
                        uint _6687_dummy_parameter;
                        _4240 = (log(((r_depth_tp1.Load(int3(int2(floor(_9949 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6687_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4218;
                    }
                    else
                    {
                        _4240 = _6680;
                    }
                    _4242 = _4240;
                }
                else
                {
                    _4242 = _4228;
                }
                _9991 = _4242;
            }
            else
            {
                _9991 = false;
            }
            _9988 = _9991;
        }
        else
        {
            _9988 = false;
        }
        bool _4247 = _9964 || _9988;
        bool _4252;
        if (_4247)
        {
            bool _6717 = all(bool2(_9945.x > 0.0f.xx.x, _9945.y > 0.0f.xx.y));
            bool _6723;
            if (_6717)
            {
                _6723 = all(bool2(_9945.x < 1.0f.xx.x, _9945.y < 1.0f.xx.y));
            }
            else
            {
                _6723 = _6717;
            }
            _4252 = _6723;
        }
        else
        {
            _4252 = _4247;
        }
        bool _4257;
        if (_4252)
        {
            bool _6728 = all(bool2(_9947.x > 0.0f.xx.x, _9947.y > 0.0f.xx.y));
            bool _6734;
            if (_6728)
            {
                _6734 = all(bool2(_9947.x < 1.0f.xx.x, _9947.y < 1.0f.xx.y));
            }
            else
            {
                _6734 = _6728;
            }
            _4257 = _6734;
        }
        else
        {
            _4257 = _4252;
        }
        float4 _10085;
        if (_4257)
        {
            float _4260 = _6592.x;
            float _4262 = _6592.y;
            float _4263 = _4260 + _4262;
            float _4268 = _6592.z + _6592.w;
            float _10006;
            if (_4263 > 0.001000000047497451305389404296875f)
            {
                _10006 = _4260 / _4263;
            }
            else
            {
                _10006 = _4169;
            }
            _10085 = float4(_4260 + (_4268 * _10006), _4262 + (_4268 * (1.0f - _10006)), 0.0f, 0.0f);
        }
        else
        {
            _10085 = _6592;
        }
        bool _6762 = (cbFI_pad0 & 1024u) != 0u;
        bool _6738 = !_6762;
        bool _6739 = !_6738;
        bool _6756;
        if (_6739)
        {
            _6756 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9975.y * cbFI_MvDepthLaneSize.x) + _9975.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6756 = _6738;
        }
        bool _6788;
        if (_6739)
        {
            _6788 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3960.y * cbFI_FlowLaneSize.x) + _3960.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6788 = _6738;
        }
        float _4303 = float(_6788);
        bool _10098;
        float4 _10183;
        float3 _11137;
        if (_6762)
        {
            bool _4313;
            if (_6756)
            {
                _4313 = all(bool2(_9945.x > 0.0f.xx.x, _9945.y > 0.0f.xx.y));
            }
            else
            {
                _4313 = _6756;
            }
            bool _4319;
            if (_4313)
            {
                _4319 = all(bool2(_9945.x < 1.0f.xx.x, _9945.y < 1.0f.xx.y));
            }
            else
            {
                _4319 = _4313;
            }
            bool _4326;
            if (_6756)
            {
                _4326 = all(bool2(_9947.x > 0.0f.xx.x, _9947.y > 0.0f.xx.y));
            }
            else
            {
                _4326 = _6756;
            }
            bool _4332;
            if (_4326)
            {
                _4332 = all(bool2(_9947.x < 1.0f.xx.x, _9947.y < 1.0f.xx.y));
            }
            else
            {
                _4332 = _4326;
            }
            bool _4339;
            if (_6788)
            {
                _4339 = all(bool2(_9948.x > 0.0f.xx.x, _9948.y > 0.0f.xx.y));
            }
            else
            {
                _4339 = _6788;
            }
            bool _4345;
            if (_4339)
            {
                _4345 = all(bool2(_9948.x < 1.0f.xx.x, _9948.y < 1.0f.xx.y));
            }
            else
            {
                _4345 = _4339;
            }
            bool _4352;
            if (_6788)
            {
                _4352 = all(bool2(_9949.x > 0.0f.xx.x, _9949.y > 0.0f.xx.y));
            }
            else
            {
                _4352 = _6788;
            }
            bool _4358;
            if (_4352)
            {
                _4358 = all(bool2(_9949.x < 1.0f.xx.x, _9949.y < 1.0f.xx.y));
            }
            else
            {
                _4358 = _4352;
            }
            bool _4360 = !_6756;
            if (_4360)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6830;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6830);
                }
            }
            bool _4365 = !_6788;
            if (_4365)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6840;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6840);
                }
            }
            if (_6756 && _4365)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6850;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6850);
                }
            }
            if (_4360 && _6788)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6860;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6860);
                }
            }
            float _4384 = float(_4319);
            float _4386 = float(_4332);
            bool _4389 = _4345 && _4358;
            float _10040;
            if (_4389)
            {
                _10040 = 1.0f;
            }
            else
            {
                _10040 = (_4345 || _4358) ? 0.5f : 0.0f;
            }
            bool _10045;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4319)) && (!_4332))
            {
                bool _4419;
                if (_4389)
                {
                    float _10043;
                    do
                    {
                        bool _6944 = all(bool2(_9948.x > 0.0f.xx.x, _9948.y > 0.0f.xx.y));
                        bool _6950;
                        if (_6944)
                        {
                            _6950 = all(bool2(_9948.x < 1.0f.xx.x, _9948.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6950 = _6944;
                        }
                        bool _6881 = !_6950;
                        bool _6888;
                        if (!_6881)
                        {
                            bool _6955 = all(bool2(_9949.x > 0.0f.xx.x, _9949.y > 0.0f.xx.y));
                            bool _6961;
                            if (_6955)
                            {
                                _6961 = all(bool2(_9949.x < 1.0f.xx.x, _9949.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6961 = _6955;
                            }
                            _6888 = !_6961;
                        }
                        else
                        {
                            _6888 = _6881;
                        }
                        if (_6888)
                        {
                            _10043 = 0.0f;
                            break;
                        }
                        uint _6968_dummy_parameter;
                        uint _6984_dummy_parameter;
                        float4 _6909 = mul(float4((float2(_9948.x, 1.0f - _9948.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9948 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6968_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6911 = _6909.w;
                        if (abs(_6911) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10043 = 0.0f;
                            break;
                        }
                        float _6922 = abs(cbFI_DeviceToViewDepth.y / ((_6909.z / _6911) - cbFI_DeviceToViewDepth.x));
                        float _6925 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9949 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6984_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10043 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6922 - _6925) / max(max(_6922, _6925), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4419 = _10043 >= 0.5f;
                }
                else
                {
                    _4419 = _4389;
                }
                bool _4427;
                if (_4419)
                {
                    _4427 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4427 = _4419;
                }
                bool _10046;
                if (_4427)
                {
                    uint _7034_dummy_parameter;
                    float2 _10044;
                    do
                    {
                        float _7060 = 1.0f - _9948.y;
                        float4 _7071 = mul(float4((float2(_9948.x, _7060) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9948 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7034_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7073 = _7071.w;
                        if (!(_7073 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10044 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7086 = ((_7071.xy / _7073.xx) + 1.0f.xx) * 0.5f;
                        _10044 = float2(_7086.x - _9948.x, _7060 - _7086.y);
                        break;
                    } while(false);
                    float2 _4440 = float2(cbFI_DisplaySize);
                    _10046 = length(((_9948 + _10044) - _9949) * _4440) <= ((0.100000001490116119384765625f * length(_10044 * _4440)) + 8.0f);
                }
                else
                {
                    _10046 = _4419;
                }
                _10045 = _10046;
            }
            else
            {
                _10045 = true;
            }
            bool _4454 = !_10045;
            bool _11885 = _4454 ? false : _4358;
            bool _11886 = _4454 ? false : _4345;
            bool _10099;
            float4 _10184;
            if (!(((_4319 && _4332) && _11886) && _11885))
            {
                float4 _4476 = _10085 * float4(_4384, _4386, float(_11886), float(_11885));
                float _4478 = dot(_4476, 1.0f.xxxx);
                bool _4481 = !(_4478 > 0.0f);
                float4 _10185;
                if (!_4481)
                {
                    _10185 = _4476 / _4478.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7108;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7108);
                    }
                    _10185 = 0.0f.xxxx;
                }
                _10184 = _10185;
                _10099 = _4481;
            }
            else
            {
                _10184 = _10085;
                _10099 = false;
            }
            _11137 = float3(_4384, _4386, _10040);
            _10183 = _10184;
            _10098 = _10099;
        }
        else
        {
            _11137 = float3(float(_6756), _4303, 0.0f);
            _10183 = _10085;
            _10098 = false;
        }
        bool _4499 = !_10098;
        float4 _10281;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4499) && _6756)
        {
            float _10180;
            do
            {
                uint4 _7248 = r_warped_motion_qdata_tp1.Load(int3(_9975, 0));
                uint _7249 = _7248.x;
                if (_7249 != 0u)
                {
                    float _10179;
                    if (_7249 == 0u)
                    {
                        _10179 = -1.0f;
                    }
                    else
                    {
                        _10179 = float((_7249 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10180 = _10179;
                    break;
                }
                int _10162;
                uint _10163;
                _10163 = _7249;
                _10162 = -1;
                uint _10178;
                for (; _10162 <= 1; _10163 = _10178, _10162++)
                {
                    _10178 = _10163;
                    for (int _10176 = -1; _10176 <= 1; )
                    {
                        _10178 = max(_10178, r_warped_motion_qdata_tp1.Load(int3(clamp(_9975 + int2(_10176, _10162), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10176++;
                        continue;
                    }
                }
                if (_10163 != 0u)
                {
                    float _10175;
                    if (_10163 == 0u)
                    {
                        _10175 = -1.0f;
                    }
                    else
                    {
                        _10175 = float((_10163 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10180 = _10175;
                    break;
                }
                uint _10165;
                _10165 = 4294967295u;
                uint _11856;
                for (int _10164 = 0; _10164 < 8; _10165 = _11856, _10164++)
                {
                    int _10168 = 0;
                    for (;;)
                    {
                        if (_10168 < 5)
                        {
                            int2 _7199 = _9975 + (_1085[_10164] * _1094[_10168].xx);
                            bool _7202 = any(bool2(_7199.x < int2(0, 0).x, _7199.y < int2(0, 0).y));
                            bool _7210;
                            if (!_7202)
                            {
                                _7210 = any(bool2(_7199.x >= cbFI_MvDepthLaneSize.x, _7199.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7210 = _7202;
                            }
                            if (_7210)
                            {
                                _11856 = _10165;
                                break;
                            }
                            uint4 _7288 = r_warped_motion_qdata_tp1.Load(int3(_7199, 0));
                            uint _7289 = _7288.x;
                            if (_7289 != 0u)
                            {
                                _11856 = min(_10165, _7289);
                                break;
                            }
                            _10168++;
                            continue;
                        }
                        else
                        {
                            _11856 = _10165;
                            break;
                        }
                    }
                }
                float _10167;
                if (_10165 == 4294967295u)
                {
                    _10167 = -1.0f;
                }
                else
                {
                    float _10166;
                    if (_10165 == 0u)
                    {
                        _10166 = -1.0f;
                    }
                    else
                    {
                        _10166 = float((_10165 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10167 = _10166;
                }
                _10180 = _10167;
                break;
            } while(false);
            float _4510 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4514 = (cbFI_NfruT2Flags & 16384u) != 0u;
            bool _4520;
            if (_4514)
            {
                _4520 = _10183.y > 0.00999999977648258209228515625f;
            }
            else
            {
                _4520 = _4514;
            }
            bool _4525;
            if (_4520)
            {
                bool _7308 = all(bool2(_9947.x > 0.0f.xx.x, _9947.y > 0.0f.xx.y));
                bool _7314;
                if (_7308)
                {
                    _7314 = all(bool2(_9947.x < 1.0f.xx.x, _9947.y < 1.0f.xx.y));
                }
                else
                {
                    _7314 = _7308;
                }
                _4525 = _7314;
            }
            else
            {
                _4525 = _4520;
            }
            float4 _10226;
            if (_4525)
            {
                float _10201;
                if (_10180 >= 0.0f)
                {
                    _10201 = _10180 - _4510;
                }
                else
                {
                    float _10197;
                    _10197 = 2.0f;
                    float _7371;
                    for (int _10196 = 0; _10196 < 24; _10197 = _7371, _10196++)
                    {
                        float _7335 = float(_10196 & 7) * 0.785398185253143310546875f;
                        int _7337 = _10196 >> 3;
                        int _10198;
                        if (_7337 == 0)
                        {
                            _10198 = 16;
                        }
                        else
                        {
                            _10198 = (_7337 == 1) ? 48 : 96;
                        }
                        uint _7403_dummy_parameter;
                        _7371 = min(_10197, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_9947 + ((cbFI_MvDepthLaneSizeRcp * float(_10198)) * float2(cos(_7335), sin(_7335))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7403_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10201 = _10197;
                }
                uint _7435_dummy_parameter;
                float4 _10227;
                if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_9947 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7435_dummy_parameter))))), 0)).x) > ((exp((_10201 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    _10227 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10227 = 1.0f.xxxx;
                }
                _10226 = _10227;
            }
            else
            {
                _10226 = 1.0f.xxxx;
            }
            bool _4552 = (cbFI_NfruT2Flags & 32768u) != 0u;
            bool _4558;
            if (_4552)
            {
                _4558 = _10183.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4558 = _4552;
            }
            bool _4563;
            if (_4558)
            {
                bool _7460 = all(bool2(_9945.x > 0.0f.xx.x, _9945.y > 0.0f.xx.y));
                bool _7466;
                if (_7460)
                {
                    _7466 = all(bool2(_9945.x < 1.0f.xx.x, _9945.y < 1.0f.xx.y));
                }
                else
                {
                    _7466 = _7460;
                }
                _4563 = _7466;
            }
            else
            {
                _4563 = _4558;
            }
            float4 _10230;
            if (_4563)
            {
                float _10221;
                if (_10180 >= 0.0f)
                {
                    _10221 = _10180 - _4510;
                }
                else
                {
                    float _10217;
                    _10217 = 2.0f;
                    float _7523;
                    for (int _10216 = 0; _10216 < 24; _10217 = _7523, _10216++)
                    {
                        float _7487 = float(_10216 & 7) * 0.785398185253143310546875f;
                        int _7489 = _10216 >> 3;
                        int _10218;
                        if (_7489 == 0)
                        {
                            _10218 = 16;
                        }
                        else
                        {
                            _10218 = (_7489 == 1) ? 48 : 96;
                        }
                        uint _7539_dummy_parameter;
                        _7523 = min(_10217, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_9945 + ((cbFI_MvDepthLaneSizeRcp * float(_10218)) * float2(cos(_7487), sin(_7487))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7539_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10221 = _10217;
                }
                uint _7587_dummy_parameter;
                float4 _10231;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_9945 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7587_dummy_parameter))))), 0)).x) > ((exp((_10221 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _9791 = _10226;
                    _9791.x = 0.0f;
                    _10231 = _9791;
                }
                else
                {
                    _10231 = _10226;
                }
                _10230 = _10231;
            }
            else
            {
                _10230 = _10226;
            }
            float4 _10282;
            if (any(bool4(_10230.x < 1.0f.xxxx.x, _10230.y < 1.0f.xxxx.y, _10230.z < 1.0f.xxxx.z, _10230.w < 1.0f.xxxx.w)))
            {
                float4 _4593 = _10183 * _10230;
                float _4595 = dot(_4593, 1.0f.xxxx);
                float4 _10283;
                if (_4595 > 0.0f)
                {
                    _10283 = _4593 / _4595.xxxx;
                }
                else
                {
                    bool _4606 = _10230.y == 0.0f;
                    bool _4612;
                    if (_4606)
                    {
                        _4612 = _10230.x > 0.0f;
                    }
                    else
                    {
                        _4612 = _4606;
                    }
                    bool _4617;
                    if (_4612)
                    {
                        bool _7612 = all(bool2(_9945.x > 0.0f.xx.x, _9945.y > 0.0f.xx.y));
                        bool _7618;
                        if (_7612)
                        {
                            _7618 = all(bool2(_9945.x < 1.0f.xx.x, _9945.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7618 = _7612;
                        }
                        _4617 = _7618;
                    }
                    else
                    {
                        _4617 = _4612;
                    }
                    float4 _10284;
                    if (_4617)
                    {
                        _10284 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4622 = _10230.x == 0.0f;
                        bool _4628;
                        if (_4622)
                        {
                            _4628 = _10230.y > 0.0f;
                        }
                        else
                        {
                            _4628 = _4622;
                        }
                        bool _4633;
                        if (_4628)
                        {
                            bool _7623 = all(bool2(_9947.x > 0.0f.xx.x, _9947.y > 0.0f.xx.y));
                            bool _7629;
                            if (_7623)
                            {
                                _7629 = all(bool2(_9947.x < 1.0f.xx.x, _9947.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7629 = _7623;
                            }
                            _4633 = _7629;
                        }
                        else
                        {
                            _4633 = _4628;
                        }
                        bool4 _11887 = _4633.xxxx;
                        _10284 = float4(_11887.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10183.x, _11887.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10183.y, _11887.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10183.z, _11887.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10183.w);
                    }
                    _10283 = _10284;
                }
                _10282 = _10283;
            }
            else
            {
                _10282 = _10183;
            }
            _10281 = _10282;
        }
        else
        {
            _10281 = _10183;
        }
        float4 _10825;
        bool _10845;
        float3 _10959;
        if (((cbFI_pad0 & 32768u) != 0u) && _4499)
        {
            bool _4650 = _10281.x > 0.00999999977648258209228515625f;
            bool _4653 = _10281.y > 0.00999999977648258209228515625f;
            bool _4662 = (_10281.z + _10281.w) > 0.0199999995529651641845703125f;
            bool _4668;
            if (_4662)
            {
                bool _7634 = all(bool2(_9948.x > 0.0f.xx.x, _9948.y > 0.0f.xx.y));
                bool _7640;
                if (_7634)
                {
                    _7640 = all(bool2(_9948.x < 1.0f.xx.x, _9948.y < 1.0f.xx.y));
                }
                else
                {
                    _7640 = _7634;
                }
                _4668 = _7640;
            }
            else
            {
                _4668 = _4662;
            }
            bool _4673;
            if (_4668)
            {
                bool _7645 = all(bool2(_9949.x > 0.0f.xx.x, _9949.y > 0.0f.xx.y));
                bool _7651;
                if (_7645)
                {
                    _7651 = all(bool2(_9949.x < 1.0f.xx.x, _9949.y < 1.0f.xx.y));
                }
                else
                {
                    _7651 = _7645;
                }
                _4673 = _7651;
            }
            else
            {
                _4673 = _4668;
            }
            bool _4680;
            if (_4673)
            {
                float _10292;
                do
                {
                    bool _7734 = all(bool2(_9948.x > 0.0f.xx.x, _9948.y > 0.0f.xx.y));
                    bool _7740;
                    if (_7734)
                    {
                        _7740 = all(bool2(_9948.x < 1.0f.xx.x, _9948.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7740 = _7734;
                    }
                    bool _7671 = !_7740;
                    bool _7678;
                    if (!_7671)
                    {
                        bool _7745 = all(bool2(_9949.x > 0.0f.xx.x, _9949.y > 0.0f.xx.y));
                        bool _7751;
                        if (_7745)
                        {
                            _7751 = all(bool2(_9949.x < 1.0f.xx.x, _9949.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7751 = _7745;
                        }
                        _7678 = !_7751;
                    }
                    else
                    {
                        _7678 = _7671;
                    }
                    if (_7678)
                    {
                        _10292 = 0.0f;
                        break;
                    }
                    uint _7758_dummy_parameter;
                    uint _7774_dummy_parameter;
                    float4 _7699 = mul(float4((float2(_9948.x, 1.0f - _9948.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9948 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7758_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7701 = _7699.w;
                    if (abs(_7701) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10292 = 0.0f;
                        break;
                    }
                    float _7712 = abs(cbFI_DeviceToViewDepth.y / ((_7699.z / _7701) - cbFI_DeviceToViewDepth.x));
                    float _7715 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9949 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7774_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10292 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7712 - _7715) / max(max(_7712, _7715), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4680 = _10292 < 0.5f;
            }
            else
            {
                _4680 = _4673;
            }
            float4 _10307;
            if (_4680)
            {
                uint _7824_dummy_parameter;
                uint _7855_dummy_parameter;
                float4 _10308;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9948 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7824_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9949 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7855_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10308 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10308 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10307 = _10308;
            }
            else
            {
                _10307 = 1.0f.xxxx;
            }
            bool _4704;
            if (_6756)
            {
                bool _7884 = all(bool2(_9945.x > 0.0f.xx.x, _9945.y > 0.0f.xx.y));
                bool _7890;
                if (_7884)
                {
                    _7890 = all(bool2(_9945.x < 1.0f.xx.x, _9945.y < 1.0f.xx.y));
                }
                else
                {
                    _7890 = _7884;
                }
                _4704 = _7890;
            }
            else
            {
                _4704 = _6756;
            }
            bool _4710;
            if (_6756)
            {
                bool _7895 = all(bool2(_9947.x > 0.0f.xx.x, _9947.y > 0.0f.xx.y));
                bool _7901;
                if (_7895)
                {
                    _7901 = all(bool2(_9947.x < 1.0f.xx.x, _9947.y < 1.0f.xx.y));
                }
                else
                {
                    _7901 = _7895;
                }
                _4710 = _7901;
            }
            else
            {
                _4710 = _6756;
            }
            bool _4716;
            if (_6788)
            {
                bool _7906 = all(bool2(_9948.x > 0.0f.xx.x, _9948.y > 0.0f.xx.y));
                bool _7912;
                if (_7906)
                {
                    _7912 = all(bool2(_9948.x < 1.0f.xx.x, _9948.y < 1.0f.xx.y));
                }
                else
                {
                    _7912 = _7906;
                }
                _4716 = _7912;
            }
            else
            {
                _4716 = _6788;
            }
            bool _4722;
            if (_6788)
            {
                bool _7917 = all(bool2(_9949.x > 0.0f.xx.x, _9949.y > 0.0f.xx.y));
                bool _7923;
                if (_7917)
                {
                    _7923 = all(bool2(_9949.x < 1.0f.xx.x, _9949.y < 1.0f.xx.y));
                }
                else
                {
                    _7923 = _7917;
                }
                _4722 = _7923;
            }
            else
            {
                _4722 = _6788;
            }
            bool _4725 = _4716 != _4722;
            bool _4731;
            if (_4725)
            {
                _4731 = _4704 || _4710;
            }
            else
            {
                _4731 = _4725;
            }
            float4 _10395;
            if (_4731)
            {
                float4 _9818 = _10307;
                _9818.z = 0.0f;
                _9818.w = 0.0f;
                _10395 = _9818;
            }
            else
            {
                _10395 = _10307;
            }
            bool _4738 = _4704 && _4650;
            bool _4741 = _4710 && _4653;
            float4 _10500;
            float3 _11036;
            if (_4738 || _4741)
            {
                float _10390;
                do
                {
                    uint4 _8062 = r_warped_motion_qdata_tp1.Load(int3(_9975, 0));
                    uint _8063 = _8062.x;
                    if (_8063 != 0u)
                    {
                        float _10389;
                        if (_8063 == 0u)
                        {
                            _10389 = -1.0f;
                        }
                        else
                        {
                            _10389 = float((_8063 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10390 = _10389;
                        break;
                    }
                    int _10372;
                    uint _10373;
                    _10373 = _8063;
                    _10372 = -1;
                    uint _10388;
                    for (; _10372 <= 1; _10373 = _10388, _10372++)
                    {
                        _10388 = _10373;
                        for (int _10386 = -1; _10386 <= 1; )
                        {
                            _10388 = max(_10388, r_warped_motion_qdata_tp1.Load(int3(clamp(_9975 + int2(_10386, _10372), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10386++;
                            continue;
                        }
                    }
                    if (_10373 != 0u)
                    {
                        float _10385;
                        if (_10373 == 0u)
                        {
                            _10385 = -1.0f;
                        }
                        else
                        {
                            _10385 = float((_10373 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10390 = _10385;
                        break;
                    }
                    uint _10375;
                    _10375 = 4294967295u;
                    uint _11857;
                    for (int _10374 = 0; _10374 < 8; _10375 = _11857, _10374++)
                    {
                        int _10378 = 0;
                        for (;;)
                        {
                            if (_10378 < 5)
                            {
                                int2 _8013 = _9975 + (_1085[_10374] * _1094[_10378].xx);
                                bool _8016 = any(bool2(_8013.x < int2(0, 0).x, _8013.y < int2(0, 0).y));
                                bool _8024;
                                if (!_8016)
                                {
                                    _8024 = any(bool2(_8013.x >= cbFI_MvDepthLaneSize.x, _8013.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8024 = _8016;
                                }
                                if (_8024)
                                {
                                    _11857 = _10375;
                                    break;
                                }
                                uint4 _8102 = r_warped_motion_qdata_tp1.Load(int3(_8013, 0));
                                uint _8103 = _8102.x;
                                if (_8103 != 0u)
                                {
                                    _11857 = min(_10375, _8103);
                                    break;
                                }
                                _10378++;
                                continue;
                            }
                            else
                            {
                                _11857 = _10375;
                                break;
                            }
                        }
                    }
                    float _10377;
                    if (_10375 == 4294967295u)
                    {
                        _10377 = -1.0f;
                    }
                    else
                    {
                        float _10376;
                        if (_10375 == 0u)
                        {
                            _10376 = -1.0f;
                        }
                        else
                        {
                            _10376 = float((_10375 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10377 = _10376;
                    }
                    _10390 = _10377;
                    break;
                } while(false);
                bool _4749 = _10390 < 0.0f;
                float _10391;
                if (_4749)
                {
                    _10391 = 0.0f;
                }
                else
                {
                    _10391 = _10390 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8124_dummy_parameter;
                uint _8156_dummy_parameter;
                float4 _10428;
                if ((_4749 && _4738) && _4741)
                {
                    uint _8188_dummy_parameter;
                    float _8212 = log(((r_depth_tm1.Load(int3(int2(floor(_9945 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8188_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8220_dummy_parameter;
                    float _8244 = log(((r_depth_tp1.Load(int3(int2(floor(_9947 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8220_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10429;
                    if (_8212 > (_8244 + 0.07999999821186065673828125f))
                    {
                        float4 _9822 = _10395;
                        _9822.x = 0.0f;
                        _10429 = _9822;
                    }
                    else
                    {
                        float4 _10430;
                        if (_8244 > (_8212 + 0.07999999821186065673828125f))
                        {
                            float4 _9824 = _10395;
                            _9824.y = 0.0f;
                            _10430 = _9824;
                        }
                        else
                        {
                            _10430 = _10395;
                        }
                        _10429 = _10430;
                    }
                    _10428 = _10429;
                }
                else
                {
                    _10428 = _10395;
                }
                float _4801 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4803 = _10390 >= 0.0f;
                float _10411;
                if (_4803)
                {
                    _10411 = _10390 - _4801;
                }
                else
                {
                    float _10407;
                    if (_4738)
                    {
                        float _10406;
                        _10406 = 2.0f;
                        float _8302;
                        for (int _10405 = 0; _10405 < 24; _10406 = _8302, _10405++)
                        {
                            float _8266 = float(_10405 & 7) * 0.785398185253143310546875f;
                            int _8268 = _10405 >> 3;
                            int _10408;
                            if (_8268 == 0)
                            {
                                _10408 = 16;
                            }
                            else
                            {
                                _10408 = (_8268 == 1) ? 48 : 96;
                            }
                            uint _8318_dummy_parameter;
                            _8302 = min(_10406, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_9945 + ((cbFI_MvDepthLaneSizeRcp * float(_10408)) * float2(cos(_8266), sin(_8266))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8318_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10407 = _10406;
                    }
                    else
                    {
                        _10407 = 0.0f;
                    }
                    _10411 = _10407;
                }
                float _10418;
                if (_4803)
                {
                    _10418 = _10390 - _4801;
                }
                else
                {
                    float _10414;
                    if (_4741)
                    {
                        float _10413;
                        _10413 = 2.0f;
                        float _8416;
                        for (int _10412 = 0; _10412 < 24; _10413 = _8416, _10412++)
                        {
                            float _8380 = float(_10412 & 7) * 0.785398185253143310546875f;
                            int _8382 = _10412 >> 3;
                            int _10415;
                            if (_8382 == 0)
                            {
                                _10415 = 16;
                            }
                            else
                            {
                                _10415 = (_8382 == 1) ? 48 : 96;
                            }
                            uint _8448_dummy_parameter;
                            _8416 = min(_10413, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_9947 + ((cbFI_MvDepthLaneSizeRcp * float(_10415)) * float2(cos(_8380), sin(_8380))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8448_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10414 = _10413;
                    }
                    else
                    {
                        _10414 = 0.0f;
                    }
                    _10418 = _10414;
                }
                float _10419;
                if (_4738)
                {
                    uint _8480_dummy_parameter;
                    _10419 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_9945 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8480_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10419 = 0.0f;
                }
                float _10420;
                if (_4741)
                {
                    uint _8500_dummy_parameter;
                    _10420 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_9947 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8500_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10420 = 0.0f;
                }
                bool _4858;
                if (_4738)
                {
                    _4858 = _10419 > ((exp((_10411 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4858 = _4738;
                }
                float4 _10436;
                if (_4858)
                {
                    float4 _9826 = _10428;
                    _9826.x = 0.0f;
                    _10436 = _9826;
                }
                else
                {
                    _10436 = _10428;
                }
                bool _4870;
                if (_4741)
                {
                    _4870 = _10420 > ((exp((_10418 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4870 = _4741;
                }
                float4 _10438;
                if (_4870)
                {
                    float4 _9828 = _10436;
                    _9828.y = 0.0f;
                    _10438 = _9828;
                }
                else
                {
                    _10438 = _10436;
                }
                float4 _10501;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4803)
                {
                    bool _4890;
                    if (_4738)
                    {
                        _4890 = _10419 < ((exp((_10411 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4890 = _4738;
                    }
                    float4 _10440;
                    if (_4890)
                    {
                        float4 _9830 = _10438;
                        _9830.x = 0.0f;
                        _10440 = _9830;
                    }
                    else
                    {
                        _10440 = _10438;
                    }
                    bool _4902;
                    if (_4741)
                    {
                        _4902 = _10420 < ((exp((_10418 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4902 = _4741;
                    }
                    float4 _10502;
                    if (_4902)
                    {
                        float4 _9832 = _10440;
                        _9832.y = 0.0f;
                        _10502 = _9832;
                    }
                    else
                    {
                        _10502 = _10440;
                    }
                    _10501 = _10502;
                }
                else
                {
                    _10501 = _10438;
                }
                _11036 = float3(_10391, log(((r_depth_tm1.Load(int3(int2(floor(_9945 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8124_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_9947 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8156_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _10500 = _10501;
            }
            else
            {
                _11036 = float3(0.0f, 0.0f, 0.5f);
                _10500 = _10395;
            }
            bool _4913 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4662;
            bool _4919;
            if (_4913)
            {
                _4919 = _4716 || _4722;
            }
            else
            {
                _4919 = _4913;
            }
            float4 _10523;
            if (_4919)
            {
                float _10495;
                do
                {
                    uint4 _8680 = r_warped_motion_qdata_tp1.Load(int3(_9975, 0));
                    uint _8681 = _8680.x;
                    if (_8681 != 0u)
                    {
                        float _10494;
                        if (_8681 == 0u)
                        {
                            _10494 = -1.0f;
                        }
                        else
                        {
                            _10494 = float((_8681 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10495 = _10494;
                        break;
                    }
                    int _10477;
                    uint _10478;
                    _10478 = _8681;
                    _10477 = -1;
                    uint _10493;
                    for (; _10477 <= 1; _10478 = _10493, _10477++)
                    {
                        _10493 = _10478;
                        for (int _10491 = -1; _10491 <= 1; )
                        {
                            _10493 = max(_10493, r_warped_motion_qdata_tp1.Load(int3(clamp(_9975 + int2(_10491, _10477), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10491++;
                            continue;
                        }
                    }
                    if (_10478 != 0u)
                    {
                        float _10490;
                        if (_10478 == 0u)
                        {
                            _10490 = -1.0f;
                        }
                        else
                        {
                            _10490 = float((_10478 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10495 = _10490;
                        break;
                    }
                    uint _10480;
                    _10480 = 4294967295u;
                    uint _11858;
                    for (int _10479 = 0; _10479 < 8; _10480 = _11858, _10479++)
                    {
                        int _10483 = 0;
                        for (;;)
                        {
                            if (_10483 < 5)
                            {
                                int2 _8631 = _9975 + (_1085[_10479] * _1094[_10483].xx);
                                bool _8634 = any(bool2(_8631.x < int2(0, 0).x, _8631.y < int2(0, 0).y));
                                bool _8642;
                                if (!_8634)
                                {
                                    _8642 = any(bool2(_8631.x >= cbFI_MvDepthLaneSize.x, _8631.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8642 = _8634;
                                }
                                if (_8642)
                                {
                                    _11858 = _10480;
                                    break;
                                }
                                uint4 _8720 = r_warped_motion_qdata_tp1.Load(int3(_8631, 0));
                                uint _8721 = _8720.x;
                                if (_8721 != 0u)
                                {
                                    _11858 = min(_10480, _8721);
                                    break;
                                }
                                _10483++;
                                continue;
                            }
                            else
                            {
                                _11858 = _10480;
                                break;
                            }
                        }
                    }
                    float _10482;
                    if (_10480 == 4294967295u)
                    {
                        _10482 = -1.0f;
                    }
                    else
                    {
                        float _10481;
                        if (_10480 == 0u)
                        {
                            _10481 = -1.0f;
                        }
                        else
                        {
                            _10481 = float((_10480 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10482 = _10481;
                    }
                    _10495 = _10482;
                    break;
                } while(false);
                float4 _10524;
                if (_10495 >= 0.0f)
                {
                    float _8742 = (exp((_10495 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4938;
                    if (_4716)
                    {
                        uint _8749_dummy_parameter;
                        _4938 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_9948 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8749_dummy_parameter))))), 0)).x) > _8742;
                    }
                    else
                    {
                        _4938 = _4716;
                    }
                    float4 _10513;
                    if (_4938)
                    {
                        float4 _9834 = _10500;
                        _9834.z = 0.0f;
                        _10513 = _9834;
                    }
                    else
                    {
                        _10513 = _10500;
                    }
                    bool _4950;
                    if (_4722)
                    {
                        uint _8769_dummy_parameter;
                        _4950 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_9949 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8769_dummy_parameter))))), 0)).x) > _8742;
                    }
                    else
                    {
                        _4950 = _4722;
                    }
                    float4 _10525;
                    if (_4950)
                    {
                        float4 _9836 = _10513;
                        _9836.w = 0.0f;
                        _10525 = _9836;
                    }
                    else
                    {
                        _10525 = _10513;
                    }
                    _10524 = _10525;
                }
                else
                {
                    _10524 = _10500;
                }
                _10523 = _10524;
            }
            else
            {
                _10523 = _10500;
            }
            bool _4958 = _4704 != _4710;
            bool _4965;
            if (_4958)
            {
                _4965 = _4704 ? _4650 : _4653;
            }
            else
            {
                _4965 = _4958;
            }
            bool _4972;
            if (_4965)
            {
                _4972 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _4972 = _4965;
            }
            float4 _10608;
            if (_4972)
            {
                bool2 _4977 = _4704.xx;
                float2 _4978 = float2(_4977.x ? _9945.x : _9947.x, _4977.y ? _9945.y : _9947.y);
                float _10515;
                if (_4704)
                {
                    uint _8789_dummy_parameter;
                    _10515 = r_depth_tm1.Load(int3(int2(floor(_4978 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8789_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _8805_dummy_parameter;
                    _10515 = r_depth_tp1.Load(int3(int2(floor(_4978 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8805_dummy_parameter))))), 0)).x;
                }
                float4x4 _10516;
                if (_4704)
                {
                    _10516 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10516 = cbFI_MotionTP1ToTM1;
                }
                float2 _10517;
                do
                {
                    float _8832 = _4978.x;
                    float _8835 = 1.0f - _4978.y;
                    float4 _8846 = mul(float4((float2(_8832, _8835) * 2.0f) - 1.0f.xx, _10515, 1.0f), _10516);
                    float _8848 = _8846.w;
                    if (!(_8848 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10517 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8861 = ((_8846.xy / _8848.xx) + 1.0f.xx) * 0.5f;
                    _10517 = float2(_8861.x - _8832, _8835 - _8861.y);
                    break;
                } while(false);
                float2 _5008 = float2(cbFI_DisplaySize);
                float4 _10609;
                if (!(length(((_4978 + _10517) - float2(_4977.x ? _9947.x : _9945.x, _4977.y ? _9947.y : _9945.y)) * _5008) <= ((0.100000001490116119384765625f * length(_10517 * _5008)) + 8.0f)))
                {
                    float4 _10610;
                    if (_4704)
                    {
                        float4 _9846 = _10523;
                        _9846.x = 0.0f;
                        _10610 = _9846;
                    }
                    else
                    {
                        float4 _9848 = _10523;
                        _9848.y = 0.0f;
                        _10610 = _9848;
                    }
                    _10609 = _10610;
                }
                else
                {
                    _10609 = _10523;
                }
                _10608 = _10609;
            }
            else
            {
                _10608 = _10523;
            }
            float4 _5033 = _10281 * _10608;
            float _5035 = dot(_5033, 1.0f.xxxx);
            float4 _10826;
            bool _10846;
            if (_5035 > 0.0f)
            {
                _10846 = _10098;
                _10826 = _5033 / _5035.xxxx;
            }
            else
            {
                bool _5046 = any(bool4(_10608.x < 1.0f.xxxx.x, _10608.y < 1.0f.xxxx.y, _10608.z < 1.0f.xxxx.z, _10608.w < 1.0f.xxxx.w));
                if (_5046)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8883;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8883);
                    }
                }
                bool4 _11890 = _5046.xxxx;
                _10846 = _5046 ? true : _10098;
                _10826 = float4(_11890.x ? 0.0f.xxxx.x : _10281.x, _11890.y ? 0.0f.xxxx.y : _10281.y, _11890.z ? 0.0f.xxxx.z : _10281.z, _11890.w ? 0.0f.xxxx.w : _10281.w);
            }
            _10959 = _11036;
            _10845 = _10846;
            _10825 = _10826;
        }
        else
        {
            _10959 = float3(0.0f, 0.0f, 0.5f);
            _10845 = _10098;
            _10825 = _10281;
        }
        uint _5055 = (cbFI_pad0 >> 24u) & 31u;
        uint _5059 = (cbFI_pad0 >> 16u) & 255u;
        bool _5061 = _5055 != 0u;
        bool _5063 = _5059 == 12u;
        bool _5066 = _5059 == 13u;
        float4 _10842;
        if ((_5061 || _5063) || _5066)
        {
            float _10611;
            do
            {
                bool _8967 = all(bool2(_9948.x > 0.0f.xx.x, _9948.y > 0.0f.xx.y));
                bool _8973;
                if (_8967)
                {
                    _8973 = all(bool2(_9948.x < 1.0f.xx.x, _9948.y < 1.0f.xx.y));
                }
                else
                {
                    _8973 = _8967;
                }
                bool _8904 = !_8973;
                bool _8911;
                if (!_8904)
                {
                    bool _8978 = all(bool2(_9949.x > 0.0f.xx.x, _9949.y > 0.0f.xx.y));
                    bool _8984;
                    if (_8978)
                    {
                        _8984 = all(bool2(_9949.x < 1.0f.xx.x, _9949.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8984 = _8978;
                    }
                    _8911 = !_8984;
                }
                else
                {
                    _8911 = _8904;
                }
                if (_8911)
                {
                    _10611 = 0.0f;
                    break;
                }
                uint _8991_dummy_parameter;
                uint _9007_dummy_parameter;
                float4 _8932 = mul(float4((float2(_9948.x, 1.0f - _9948.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9948 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8991_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8934 = _8932.w;
                if (abs(_8934) < 9.9999999747524270787835121154785e-07f)
                {
                    _10611 = 0.0f;
                    break;
                }
                float _8945 = abs(cbFI_DeviceToViewDepth.y / ((_8932.z / _8934) - cbFI_DeviceToViewDepth.x));
                float _8948 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9949 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9007_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10611 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8945 - _8948) / max(max(_8945, _8948), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9055 = all(bool2(_9949.x > 0.0f.xx.x, _9949.y > 0.0f.xx.y));
            bool _9061;
            if (_9055)
            {
                _9061 = all(bool2(_9949.x < 1.0f.xx.x, _9949.y < 1.0f.xx.y));
            }
            else
            {
                _9061 = _9055;
            }
            float _10612;
            if (_9061)
            {
                uint _9068_dummy_parameter;
                _10612 = length((_5842 + (r_motion_tp1.Load(int3(int2(floor(_9949 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9068_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10612 = 1000000.0f;
            }
            float _10623;
            if ((_5055 & 1u) != 0u)
            {
                _10623 = _10611;
            }
            else
            {
                _10623 = 1.0f;
            }
            float _10624;
            if ((_5055 & 2u) != 0u)
            {
                _10624 = _10623 * (1.0f - smoothstep(2.0f, 8.0f, _10612));
            }
            else
            {
                _10624 = _10623;
            }
            float _10625;
            if ((_5055 & 4u) != 0u)
            {
                _10625 = _10624 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6563 - _6571) - length(_6547 - _6555))));
            }
            else
            {
                _10625 = _10624;
            }
            float _10836;
            if ((_5055 & 8u) != 0u)
            {
                _10836 = lerp(1.0f, _10625, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6547 - _6555)));
            }
            else
            {
                _10836 = _10625;
            }
            bool _5141 = (_5055 & 16u) != 0u;
            bool _5150;
            if (_5141)
            {
                _5150 = length(_9943 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5150 = _5141;
            }
            float _11892 = _5150 ? 1.0f : _10836;
            bool _5156 = _5061 && _6756;
            bool _5161;
            if (_5156)
            {
                bool _9093 = all(bool2(_9945.x > 0.0f.xx.x, _9945.y > 0.0f.xx.y));
                bool _9099;
                if (_9093)
                {
                    _9099 = all(bool2(_9945.x < 1.0f.xx.x, _9945.y < 1.0f.xx.y));
                }
                else
                {
                    _9099 = _9093;
                }
                _5161 = _9099;
            }
            else
            {
                _5161 = _5156;
            }
            bool _5166;
            if (_5161)
            {
                bool _9104 = all(bool2(_9947.x > 0.0f.xx.x, _9947.y > 0.0f.xx.y));
                bool _9110;
                if (_9104)
                {
                    _9110 = all(bool2(_9947.x < 1.0f.xx.x, _9947.y < 1.0f.xx.y));
                }
                else
                {
                    _9110 = _9104;
                }
                _5166 = _9110;
            }
            else
            {
                _5166 = _5161;
            }
            float4 _10843;
            if (_5166)
            {
                float _5172 = _10825.x + _10825.y;
                float _5181 = (_10825.z + _10825.w) * (1.0f - _11892);
                float _10839;
                if (_5172 > 9.9999997473787516355514526367188e-06f)
                {
                    _10839 = _10825.x / _5172;
                }
                else
                {
                    _10839 = _4169;
                }
                _10843 = float4(_10825.x + (_5181 * _10839), _10825.y + (_5181 * (1.0f - _10839)), _10825.zw * _11892);
            }
            else
            {
                _10843 = _10825;
            }
            _10842 = _10843;
        }
        else
        {
            _10842 = _10825;
        }
        float3 _11660;
        if (_10845)
        {
            float3 _9116 = r_current_interpolation_source.Load(int3(_3558, 0)).xyz;
            float3 _11661;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6756)
            {
                uint _9123_dummy_parameter;
                float _10950;
                _10950 = r_depth_tm1.Load(int3(int2(floor(_9945 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9123_dummy_parameter))))), 0)).x;
                float _5293;
                for (int _10949 = 0; _10949 < 24; _10950 = _5293, _10949++)
                {
                    float _5265 = float(_10949 & 7) * 0.785398185253143310546875f;
                    int _5267 = _10949 >> 3;
                    int _11711;
                    if (_5267 == 0)
                    {
                        _11711 = 16;
                    }
                    else
                    {
                        _11711 = (_5267 == 1) ? 48 : 96;
                    }
                    uint _9143_dummy_parameter;
                    _5293 = max(_10950, r_depth_tm1.Load(int3(int2(floor(clamp(_9945 + ((cbFI_MvDepthLaneSizeRcp * float(_11711)) * float2(cos(_5265), sin(_5265))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9143_dummy_parameter))))), 0)).x);
                }
                float2 _10951;
                do
                {
                    float _9165 = 1.0f - _9945.y;
                    float4 _9176 = mul(float4((float2(_9945.x, _9165) * 2.0f) - 1.0f.xx, _10950, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9178 = _9176.w;
                    if (!(_9178 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10951 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9191 = ((_9176.xy / _9178.xx) + 1.0f.xx) * 0.5f;
                    _10951 = float2(_9191.x - _9945.x, _9165 - _9191.y);
                    break;
                } while(false);
                float2 _5304 = _9945 + _10951;
                bool _9209 = all(bool2(_5304.x > 0.0f.xx.x, _5304.y > 0.0f.xx.y));
                bool _9215;
                if (_9209)
                {
                    _9215 = all(bool2(_5304.x < 1.0f.xx.x, _5304.y < 1.0f.xx.y));
                }
                else
                {
                    _9215 = _9209;
                }
                float3 _11662;
                if (_9215)
                {
                    float _5310 = abs(cbFI_DeviceToViewDepth.y / (_10950 - cbFI_DeviceToViewDepth.x));
                    uint _9235_dummy_parameter;
                    int2 _9235 = int2(spvTextureSize(r_depth_m2, uint(0), _9235_dummy_parameter));
                    float _5314 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5304 * float2(_9235))), int2(0, 0), _9235 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _11667;
                    if (abs(_5314 - _5310) <= (0.20000000298023223876953125f * max(_5314, _5310)))
                    {
                        uint _9269_dummy_parameter;
                        int2 _9269 = int2(spvTextureSize(r_colour_m2, uint(0), _9269_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9292;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9292);
                        }
                        _11667 = r_colour_m2.Load(int3(clamp(int2(floor(_5304 * float2(_9269))), int2(0, 0), _9269 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9302;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9302);
                        }
                        _11667 = _9116;
                    }
                    _11662 = _11667;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9312;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9312);
                    }
                    _11662 = _9116;
                }
                _11661 = _11662;
            }
            else
            {
                _11661 = _9116;
            }
            _11660 = _11661;
        }
        else
        {
            _11660 = (((_6547 * _10842.x) + (_6555 * _10842.y)) + (_6563 * _10842.z)) + (_6571 * _10842.w);
        }
        uint _5342 = cbFI_pad0 & 255u;
        bool _11552;
        float3 _11659;
        if (_5342 != 0u)
        {
            float3 _5347 = r_present_backbuffer.Load(int3(_3558, 0)).xyz;
            float3 _5351 = r_current_interpolation_source.Load(int3(_3558, 0)).xyz;
            float3 _5355 = abs(_5347 - _5351);
            float3 _10954;
            if (_5342 == 2u)
            {
                _10954 = (abs(_5351) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _10954 = 0.000244140625f.xxx;
            }
            bool _5371 = any(bool3(_5355.x > _10954.x, _5355.y > _10954.y, _5355.z > _10954.z));
            bool3 _11893 = _5371.xxx;
            _11659 = float3(_11893.x ? _5347.x : _11660.x, _11893.y ? _5347.y : _11660.y, _11893.z ? _5347.z : _11660.z);
            _11552 = _5371;
        }
        else
        {
            _11659 = _11660;
            _11552 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9327;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9327);
        }
        float3 _11642;
        if (_5059 == 1u)
        {
            _11642 = lerp(_6547, _6555, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _11643;
            if (_5059 == 2u)
            {
                _11643 = lerp(_6563, _6571, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _11644;
                if (_5059 == 3u)
                {
                    _11644 = float(_11552).xxx;
                }
                else
                {
                    float3 _11645;
                    if (_5059 == 4u)
                    {
                        _11645 = float3(((_9943 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _11646;
                        if (_5059 == 5u)
                        {
                            _11646 = float3(((_5842 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _11647;
                            if (_5059 == 6u)
                            {
                                _11647 = float3(_10842.xy, _10842.z + _10842.w);
                            }
                            else
                            {
                                float3 _11648;
                                if (_5059 == 7u)
                                {
                                    _11648 = r_current_interpolation_source.Load(int3(_3558, 0)).xyz;
                                }
                                else
                                {
                                    float3 _11649;
                                    if (_5059 == 8u)
                                    {
                                        _11649 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3944, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _11650;
                                        if (_5063)
                                        {
                                            uint _9349_dummy_parameter;
                                            uint _9381_dummy_parameter;
                                            _11650 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3944 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9349_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3944 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9381_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _11651;
                                            if (_5066)
                                            {
                                                _11651 = _6563;
                                            }
                                            else
                                            {
                                                float3 _11652;
                                                if (_5059 == 20u)
                                                {
                                                    _11652 = _6547;
                                                }
                                                else
                                                {
                                                    float3 _11653;
                                                    if (_5059 == 21u)
                                                    {
                                                        _11653 = _6555;
                                                    }
                                                    else
                                                    {
                                                        float3 _11654;
                                                        if (_5059 == 22u)
                                                        {
                                                            _11654 = _6571;
                                                        }
                                                        else
                                                        {
                                                            float3 _11655;
                                                            if (_5059 == 18u)
                                                            {
                                                                _11655 = _11321;
                                                            }
                                                            else
                                                            {
                                                                float3 _11656;
                                                                if (_5059 == 19u)
                                                                {
                                                                    _11656 = _11137;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _11895 = (_5059 == 23u).xxx;
                                                                    _11656 = float3(_11895.x ? _10959.x : _11659.x, _11895.y ? _10959.y : _11659.y, _11895.z ? _10959.z : _11659.z);
                                                                }
                                                                _11655 = _11656;
                                                            }
                                                            _11654 = _11655;
                                                        }
                                                        _11653 = _11654;
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
                                _11647 = _11648;
                            }
                            _11646 = _11647;
                        }
                        _11645 = _11646;
                    }
                    _11644 = _11645;
                }
                _11643 = _11644;
            }
            _11642 = _11643;
        }
        float3 _11641;
        if ((_5059 >= 9u) && (_5059 <= 11u))
        {
            uint _5535 = 64u + uint((_9975.y * cbFI_MvDepthLaneSize.x) + _9975.x);
            uint _5539 = rw_nfru_diagnostics.Load<uint>(_5535 * 4 + 0) & 15u;
            float3 _11672;
            if (_5059 == 10u)
            {
                float3 _11640;
                if ((rw_nfru_diagnostics.Load<uint>(_5535 * 4 + 0) & 32u) != 0u)
                {
                    _11640 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _11639;
                    if ((rw_nfru_diagnostics.Load<uint>(_5535 * 4 + 0) & 16u) != 0u)
                    {
                        _11639 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5560 = ((rw_nfru_diagnostics.Load<uint>(_5535 * 4 + 0) & 64u) != 0u).xxx;
                        _11639 = float3(_5560.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5560.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5560.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _11640 = _11639;
                }
                _11672 = _11640;
            }
            else
            {
                float3 _11673;
                if (_5059 == 11u)
                {
                    uint _5573 = (rw_nfru_diagnostics.Load<uint>(_5535 * 4 + 0) >> 8u) & 15u;
                    uint _5576 = (rw_nfru_diagnostics.Load<uint>(_5535 * 4 + 0) >> 12u) & 15u;
                    float3 _11632;
                    if ((_5539 == 2u) || (_5539 == 3u))
                    {
                        _11632 = _3271[_5539];
                    }
                    else
                    {
                        bool _5588 = _5573 == 3u;
                        bool _5590 = _5576 == 3u;
                        float3 _11633;
                        if (_5588 && _5590)
                        {
                            _11633 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _11634;
                            if (_5588)
                            {
                                _11634 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _11635;
                                if (_5590)
                                {
                                    _11635 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _11636;
                                    if ((_5573 == 4u) || (_5576 == 4u))
                                    {
                                        _11636 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _11637;
                                        if ((_5573 == 1u) || (_5576 == 1u))
                                        {
                                            _11637 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _11897 = (_5539 == 1u).xxx;
                                            _11637 = float3(_11897.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _11897.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _11897.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _11636 = _11637;
                                    }
                                    _11635 = _11636;
                                }
                                _11634 = _11635;
                            }
                            _11633 = _11634;
                        }
                        _11632 = _11633;
                    }
                    _11673 = _11632;
                }
                else
                {
                    _11673 = _3271[min(_5539, 7u)];
                }
                _11672 = _11673;
            }
            _11641 = _11672;
        }
        else
        {
            _11641 = _11642;
        }
        float4 _11676;
        if ((_5059 >= 14u) && (_5059 <= 16u))
        {
            float2 _11674;
            if (_5059 == 14u)
            {
                uint _5646_dummy_parameter;
                uint _5652_dummy_parameter;
                _11674 = r_flow_tm1.Load(int3(clamp(int2(floor(_3944 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5646_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5652_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _11675;
                if (_5059 == 16u)
                {
                    uint _9432 = r_warped_flow_qdata_tm1.Load(int3(_3960, 0)).x & 2147483647u;
                    uint _9464 = uint(max((int((_9432 >> 16u) & 15u) - 6), 0));
                    _11675 = ((float2(float((1 - (2 * int((_9432 >> 15u) & 1u))) * int(((_9432 >> uint(7)) & 127u) << _9464)), float((1 - (2 * int((_9432 >> 14u) & 1u))) * int((_9432 & 127u) << _9464))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _11675 = _5842 * float2(cbFI_DisplaySize);
                }
                _11674 = _11675;
            }
            uint2 _5685 = uint2(clamp(round(_11674 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5687 = _5685.x;
            uint _5694 = _5685.y;
            _11676 = float4(float(_5687 & 255u), float((_5687 >> 8u) | ((_5694 & 15u) << 4u)), float(_5694 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _11677;
            if (_5059 == 17u)
            {
                _11677 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3960, 0)).x != 0u), _4303, 0.0f, 1.0f);
            }
            else
            {
                _11677 = float4(_11641, 1.0f);
            }
            _11676 = _11677;
        }
        rw_output[_3558] = _11676.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5738 = ((uint(_3558.y) * uint(cbFI_DisplaySize.x)) + uint(_3558.x)) * 6u;
            uint _9510 = spvPackHalf2x16(clamp(_6546.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5738 * 4 + 0, (((_9510 & 32767u) >> 4u) | ((((_9510 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6546.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9545 = spvPackHalf2x16(clamp(_6554.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5738 + 1u) * 4 + 0, (((_9545 & 32767u) >> 4u) | ((((_9545 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6554.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9580 = spvPackHalf2x16(clamp(_6562.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5738 + 2u) * 4 + 0, (((_9580 & 32767u) >> 4u) | ((((_9580 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6562.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9615 = spvPackHalf2x16(clamp(_6570.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5738 + 3u) * 4 + 0, (((_9615 & 32767u) >> 4u) | ((((_9615 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6570.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9642 = r_current_interpolation_source.Load(int3(_3558, 0));
            uint _9656 = spvPackHalf2x16(clamp(_9642.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5738 + 4u) * 4 + 0, (((_9656 & 32767u) >> 4u) | ((((_9656 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9642.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _11710;
            if (_11552 || (_5059 != 0u))
            {
                _11710 = 4294967295u;
            }
            else
            {
                uint _9691 = spvPackHalf2x16(clamp(_11676.xy, 0.0f.xx, 65000.0f.xx));
                _11710 = (((_9691 & 32767u) >> 4u) | ((((_9691 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_11676.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5738 + 5u) * 4 + 0, _11710);
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
