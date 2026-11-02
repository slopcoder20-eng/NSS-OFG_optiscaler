struct InputTensorPacked_t
{
    uint rgbM1MV_rP1MV;
    uint gbP1MV_rgM1OF;
    uint bM1OF_rgbP1OF;
    uint depth_disMask;
};

static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1648[4] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1) };

cbuffer cbFI_t : register(b9, space0)
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

RWByteAddressBuffer rw_in_tensor : register(u8, space0);
RWByteAddressBuffer rw_nfru_diagnostics : register(u10, space0);
Texture2D<float4> r_depth_tp1 : register(t4, space0);
Texture2D<float4> r_depth_tm1 : register(t5, space0);
Texture2D<float4> r_mv_holes_tm1 : register(t7, space0);
Texture2D<float4> r_mv_holes_tp1 : register(t6, space0);
Texture2D<float4> r_warped_filled_motion_tp1 : register(t0, space0);
Texture2D<float4> r_warped_filled_flow_tm1 : register(t1, space0);
Texture2D<float4> r_previous_interpolation_source : register(t2, space0);
Texture2D<float4> r_current_interpolation_source : register(t3, space0);

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

void comp_main()
{
    int2 _1749 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1749.x >= cbFI_InputTensorSize.x, _1749.y >= cbFI_InputTensorSize.y)))
        {
            break;
        }
        int _1941 = _1749.x;
        int2 _5681;
        if (_1941 >= cbFI_FlowLaneSize.x)
        {
            int2 _5497 = _1749;
            _5497.x = (cbFI_FlowLaneSize.x - 1) - (_1941 - cbFI_FlowLaneSize.x);
            _5681 = _5497;
        }
        else
        {
            _5681 = _1749;
        }
        int2 _5682;
        if (_5681.y >= cbFI_FlowLaneSize.y)
        {
            int2 _5504 = _5681;
            _5504.y = (cbFI_FlowLaneSize.y - 1) - (_5681.y - cbFI_FlowLaneSize.y);
            _5682 = _5504;
        }
        else
        {
            _5682 = _5681;
        }
        float2 _1980 = (float2(_5682) + 0.5f.xx) * cbFI_FlowLaneSizeRcp;
        int2 _1986 = int2(floor(_1980 * float2(cbFI_MvDepthLaneSize)));
        int2 _1992 = int2(floor(_1980 * float2(cbFI_FlowLaneSize)));
        float2 _2384 = r_warped_filled_flow_tm1.Load(int3(_1992, 0)).xy;
        float2 _2390 = r_warped_filled_motion_tp1.Load(int3(_1986, 0)).xy;
        bool _2412 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5683;
        if (_2412)
        {
            float _2425 = ((2.0f * _1980.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5683 = float2(atan(_2425) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _1980.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2425 * _2425))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5683 = _1980;
        }
        float2 _5684;
        if (_2412)
        {
            float2 _2500 = clamp((((_5683 + (_2390 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _2503 = tan(_2500.x);
            _5684 = (float2(_2503 / cbFI_DeviceToViewDepth.z, (tan(_2500.y) * sqrt(1.0f + (_2503 * _2503))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _5684 = _5683 + (_2390 * cbFI_Timestep);
        }
        float _2007 = cbFI_Timestep - 1.0f;
        float2 _5685;
        if (_2412)
        {
            float2 _2571 = clamp((((_5683 + (_2390 * _2007)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _2574 = tan(_2571.x);
            _5685 = (float2(_2574 / cbFI_DeviceToViewDepth.z, (tan(_2571.y) * sqrt(1.0f + (_2574 * _2574))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _5685 = _5683 + (_2390 * _2007);
        }
        float _2012 = -cbFI_Timestep;
        float2 _5686;
        if (_2412)
        {
            float2 _2642 = clamp((((_5683 + (_2384 * _2012)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _2645 = tan(_2642.x);
            _5686 = (float2(_2645 / cbFI_DeviceToViewDepth.z, (tan(_2642.y) * sqrt(1.0f + (_2645 * _2645))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _5686 = _5683 + (_2384 * _2012);
        }
        float _2017 = 1.0f - cbFI_Timestep;
        float2 _5687;
        if (_2412)
        {
            float2 _2713 = clamp((((_5683 + (_2384 * _2017)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _2716 = tan(_2713.x);
            _5687 = (float2(_2716 / cbFI_DeviceToViewDepth.z, (tan(_2713.y) * sqrt(1.0f + (_2716 * _2716))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _5687 = _5683 + (_2384 * _2017);
        }
        bool _2022 = _5685.x <= 0.0f;
        bool _2029;
        if (!_2022)
        {
            _2029 = _5685.x >= 1.0f;
        }
        else
        {
            _2029 = _2022;
        }
        bool _2043;
        if (!_2029)
        {
            bool _2034 = _5685.y <= 0.0f;
            bool _2041;
            if (!_2034)
            {
                _2041 = _5685.y >= 1.0f;
            }
            else
            {
                _2041 = _2034;
            }
            _2043 = _2041;
        }
        else
        {
            _2043 = _2029;
        }
        bool _2046 = _5684.x <= 0.0f;
        bool _2053;
        if (!_2046)
        {
            _2053 = _5684.x >= 1.0f;
        }
        else
        {
            _2053 = _2046;
        }
        bool _2067;
        if (!_2053)
        {
            bool _2058 = _5684.y <= 0.0f;
            bool _2065;
            if (!_2058)
            {
                _2065 = _5684.y >= 1.0f;
            }
            else
            {
                _2065 = _2058;
            }
            _2067 = _2065;
        }
        else
        {
            _2067 = _2053;
        }
        bool _2070 = _5686.x <= 0.0f;
        bool _2077;
        if (!_2070)
        {
            _2077 = _5686.x >= 1.0f;
        }
        else
        {
            _2077 = _2070;
        }
        bool _2091;
        if (!_2077)
        {
            bool _2082 = _5686.y <= 0.0f;
            bool _2089;
            if (!_2082)
            {
                _2089 = _5686.y >= 1.0f;
            }
            else
            {
                _2089 = _2082;
            }
            _2091 = _2089;
        }
        else
        {
            _2091 = _2077;
        }
        bool _2094 = _5687.x <= 0.0f;
        bool _2101;
        if (!_2094)
        {
            _2101 = _5687.x >= 1.0f;
        }
        else
        {
            _2101 = _2094;
        }
        bool _2115;
        if (!_2101)
        {
            bool _2106 = _5687.y <= 0.0f;
            bool _2113;
            if (!_2106)
            {
                _2113 = _5687.y >= 1.0f;
            }
            else
            {
                _2113 = _2106;
            }
            _2115 = _2113;
        }
        else
        {
            _2115 = _2101;
        }
        bool _2748 = !((cbFI_pad0 & 1024u) != 0u);
        bool _2749 = !_2748;
        bool _2766;
        if (_2749)
        {
            _2766 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_1986.y * cbFI_MvDepthLaneSize.x) + _1986.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _2766 = _2748;
        }
        bool _2798;
        if (_2749)
        {
            _2798 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_1992.y * cbFI_FlowLaneSize.x) + _1992.x)) * 4 + 0) != 0u;
        }
        else
        {
            _2798 = _2748;
        }
        bool _2121 = !_2766;
        if (_2121)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2834;
                rw_nfru_diagnostics.InterlockedAdd(240, 1u, _2834);
            }
        }
        bool _6018 = _2121 ? true : _2067;
        bool _6019 = _2121 ? true : _2043;
        bool _2126 = !_2798;
        if (_2126)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2844;
                rw_nfru_diagnostics.InterlockedAdd(244, 1u, _2844);
            }
        }
        bool _6020 = _2126 ? true : _2115;
        bool _6021 = _2126 ? true : _2091;
        uint _2852_dummy_parameter;
        float _2137 = 1.0f - float(_6019);
        float _2150 = float(((r_mv_holes_tp1.Load(int3(_1986, 0)).x * _2137) - (float(r_mv_holes_tm1.Load(int3(int2(floor(_5684 * float2(int2(spvTextureSize(r_mv_holes_tm1, uint(0), _2852_dummy_parameter))))), 0)).x != 0.0f) * _2137)) < 0.0f);
        float3 _5840;
        if (!_6018)
        {
            _5840 = r_previous_interpolation_source.Load(int3(int2(_5684 * float2(cbFI_DisplaySize)), 0)).xyz;
        }
        else
        {
            _5840 = 0.0f.xxx;
        }
        float3 _5863;
        if (!_6019)
        {
            _5863 = r_current_interpolation_source.Load(int3(int2(_5685 * float2(cbFI_DisplaySize)), 0)).xyz;
        }
        else
        {
            _5863 = 0.0f.xxx;
        }
        float3 _5886;
        if (!_6021)
        {
            _5886 = r_previous_interpolation_source.Load(int3(int2(_5686 * float2(cbFI_DisplaySize)), 0)).xyz;
        }
        else
        {
            _5886 = 0.0f.xxx;
        }
        float3 _5909;
        if (!_6020)
        {
            _5909 = r_current_interpolation_source.Load(int3(int2(_5687 * float2(cbFI_DisplaySize)), 0)).xyz;
        }
        else
        {
            _5909 = 0.0f.xxx;
        }
        uint _2198 = (uint(_5682.x) * 10000u) + uint(_5682.y);
        float3 _5836;
        if (_6018)
        {
            uint _2921 = _2198 + cbFI_RandomSeed;
            uint _2941 = ((_2921 ^ 61u) ^ (_2921 >> uint(16))) * 9u;
            uint _2947 = (_2941 ^ (_2941 >> uint(4))) * 668265261u;
            uint _2963 = (_2198 + 2654435769u) + cbFI_RandomSeed;
            uint _2983 = ((_2963 ^ 61u) ^ (_2963 >> uint(16))) * 9u;
            uint _2989 = (_2983 ^ (_2983 >> uint(4))) * 668265261u;
            uint _3005 = (_2198 + 1013904242u) + cbFI_RandomSeed;
            uint _3025 = ((_3005 ^ 61u) ^ (_3005 >> uint(16))) * 9u;
            uint _3031 = (_3025 ^ (_3025 >> uint(4))) * 668265261u;
            _5836 = float3(asfloat(((_2947 ^ (_2947 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_2989 ^ (_2989 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3031 ^ (_3031 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f);
        }
        else
        {
            _5836 = _5840;
        }
        float3 _5859;
        if (_6019)
        {
            uint _3047 = (_2198 + 3668340011u) + cbFI_RandomSeed;
            uint _3067 = ((_3047 ^ 61u) ^ (_3047 >> uint(16))) * 9u;
            uint _3073 = (_3067 ^ (_3067 >> uint(4))) * 668265261u;
            uint _3089 = (_2198 + 2027808484u) + cbFI_RandomSeed;
            uint _3109 = ((_3089 ^ 61u) ^ (_3089 >> uint(16))) * 9u;
            uint _3115 = (_3109 ^ (_3109 >> uint(4))) * 668265261u;
            uint _3131 = (_2198 + 387276957u) + cbFI_RandomSeed;
            uint _3151 = ((_3131 ^ 61u) ^ (_3131 >> uint(16))) * 9u;
            uint _3157 = (_3151 ^ (_3151 >> uint(4))) * 668265261u;
            _5859 = float3(asfloat(((_3073 ^ (_3073 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3115 ^ (_3115 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3157 ^ (_3157 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f);
        }
        else
        {
            _5859 = _5863;
        }
        float3 _5882;
        if (_6021)
        {
            uint _3173 = (_2198 + 3041712726u) + cbFI_RandomSeed;
            uint _3193 = ((_3173 ^ 61u) ^ (_3173 >> uint(16))) * 9u;
            uint _3199 = (_3193 ^ (_3193 >> uint(4))) * 668265261u;
            uint _3215 = (_2198 + 1401181199u) + cbFI_RandomSeed;
            uint _3235 = ((_3215 ^ 61u) ^ (_3215 >> uint(16))) * 9u;
            uint _3241 = (_3235 ^ (_3235 >> uint(4))) * 668265261u;
            uint _3257 = (_2198 + 4055616968u) + cbFI_RandomSeed;
            uint _3277 = ((_3257 ^ 61u) ^ (_3257 >> uint(16))) * 9u;
            uint _3283 = (_3277 ^ (_3277 >> uint(4))) * 668265261u;
            _5882 = float3(asfloat(((_3199 ^ (_3199 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3241 ^ (_3241 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3283 ^ (_3283 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f);
        }
        else
        {
            _5882 = _5886;
        }
        float3 _5905;
        if (_6020)
        {
            uint _3299 = (_2198 + 2415085441u) + cbFI_RandomSeed;
            uint _3319 = ((_3299 ^ 61u) ^ (_3299 >> uint(16))) * 9u;
            uint _3325 = (_3319 ^ (_3319 >> uint(4))) * 668265261u;
            uint _3341 = (_2198 + 774553914u) + cbFI_RandomSeed;
            uint _3361 = ((_3341 ^ 61u) ^ (_3341 >> uint(16))) * 9u;
            uint _3367 = (_3361 ^ (_3361 >> uint(4))) * 668265261u;
            uint _3383 = (_2198 + 3428989683u) + cbFI_RandomSeed;
            uint _3403 = ((_3383 ^ 61u) ^ (_3383 >> uint(16))) * 9u;
            uint _3409 = (_3403 ^ (_3403 >> uint(4))) * 668265261u;
            _5905 = float3(asfloat(((_3325 ^ (_3325 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3367 ^ (_3367 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3409 ^ (_3409 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f);
        }
        else
        {
            _5905 = _5909;
        }
        uint _3418_dummy_parameter;
        float2 _3419 = float2(int2(spvTextureSize(r_depth_tm1, uint(0), _3418_dummy_parameter)));
        uint _3423_dummy_parameter;
        float2 _3424 = float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3423_dummy_parameter)));
        int2 _2245 = int2(floor(_5684 * _3419));
        int2 _2250 = int2(floor(_5685 * _3424));
        uint2 _3444 = uint2(_2245);
        uint2 _3446 = uint2(int2(_3419));
        bool _3448 = all(bool2(_3444.x < _3446.x, _3444.y < _3446.y));
        bool _3455;
        if (_3448)
        {
            _3455 = all(bool2(_3444.x >= uint2(0u, 0u).x, _3444.y >= uint2(0u, 0u).y));
        }
        else
        {
            _3455 = _3448;
        }
        float _6022 = (!_3455) ? 1.0f : r_depth_tm1.Load(int3(_2245, 0)).x;
        uint2 _3459 = uint2(_2250);
        uint2 _3461 = uint2(int2(_3424));
        bool _3463 = all(bool2(_3459.x < _3461.x, _3459.y < _3461.y));
        bool _3470;
        if (_3463)
        {
            _3470 = all(bool2(_3459.x >= uint2(0u, 0u).x, _3459.y >= uint2(0u, 0u).y));
        }
        else
        {
            _3470 = _3463;
        }
        bool _3575;
        float _6023 = (!_3470) ? 1.0f : r_depth_tp1.Load(int3(_2250, 0)).x;
        float4x4 _5791;
        do
        {
            float4x4 _3551;
            bool _5790;
            do
            {
                _3551 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                _3575 = (cbFI_NfruT2Flags & 524288u) == 0u;
                if (_3575)
                {
                    _5790 = false;
                    break;
                }
                uint _3585 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                if (rw_nfru_diagnostics.Load<uint>((_3585 + 32u) * 4 + 0) != 1u)
                {
                    _5790 = false;
                    break;
                }
                uint _5787;
                _5787 = 0u;
                for (; _5787 < 4u; _5787++)
                {
                    for (uint _5788 = 0u; _5788 < 4u; )
                    {
                        _3551[_5787][_5788] = asfloat(rw_nfru_diagnostics.Load<uint>((((_3585 + 16u) + (_5787 * 4u)) + _5788) * 4 + 0));
                        _5788++;
                        continue;
                    }
                }
                _5790 = true;
                break;
            } while(false);
            if (_5790)
            {
                _5791 = _3551;
                break;
            }
            _5791 = cbFI_MotionTM1ToTP1;
            break;
        } while(false);
        float4 _3541 = mul(float4((float2(_5684.x, 1.0f - _5684.y) * 2.0f) - 1.0f.xx, _6022, 1.0f), _5791);
        float _3546 = _3541.z / _3541.w;
        float4x4 _5796;
        do
        {
            float4x4 _3684;
            bool _5795;
            do
            {
                _3684 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                if (_3575)
                {
                    _5795 = false;
                    break;
                }
                uint _3718 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                if (rw_nfru_diagnostics.Load<uint>((_3718 + 32u) * 4 + 0) != 1u)
                {
                    _5795 = false;
                    break;
                }
                uint _5792;
                _5792 = 0u;
                for (; _5792 < 4u; _5792++)
                {
                    for (uint _5793 = 0u; _5793 < 4u; )
                    {
                        _3684[_5792][_5793] = asfloat(rw_nfru_diagnostics.Load<uint>(((_3718 + (_5792 * 4u)) + _5793) * 4 + 0));
                        _5793++;
                        continue;
                    }
                }
                _5795 = true;
                break;
            } while(false);
            if (_5795)
            {
                _5796 = _3684;
                break;
            }
            _5796 = cbFI_MotionTP1ToTM1;
            break;
        } while(false);
        float2 _3820;
        float _3888;
        float _3891;
        float4 _3897;
        float4 _3674 = mul(float4((float2(_5685.x, 1.0f - _5685.y) * 2.0f) - 1.0f.xx, _6023, 1.0f), _5796);
        float _3679 = _3674.z / _3674.w;
        float _5797;
        do
        {
            _3820 = float2(cbFI_RenderSize);
            _3897 = cbFI_DeviceToViewDepth;
            _3888 = _3897.y;
            _3891 = _3897.x;
            float _3893 = _3888 / (_6023 - _3891);
            float _3908 = _3888 / (_3546 - _3891);
            float _3828 = _3893 - _3908;
            if (_3828 <= 0.0f)
            {
                _5797 = 0.0f;
                break;
            }
            float _3962 = _3888 / (max(_3546, _6023) - _3891);
            float2 _3974 = ((float2(int2(_3820 * 0.5f)) / float2(int2(_3820))) * float2(2.0f, -2.0f)) + float2(-1.0f, 1.0f);
            float _3848 = length(_3820);
            _5797 = 1.0f - pow(clamp((((1.3699999726668465882539749145508e-05f * (length(float3((_3897.z * (-1.0f)) * _3962, _3897.w * _3962, _3962)) / length(float3((_3897.z * _3974.x) * _3962, (_3897.w * _3974.y) * _3962, _3962)))) * _3848) * max(_3893, _3908)) / _3828, 0.0f, 1.0f), lerp(1.0f, 3.0f, clamp(_3848 * 0.00045394556946121156215667724609375f, 0.0f, 1.0f)));
            break;
        } while(false);
        float _5798;
        do
        {
            float _4158 = _3888 / (_6022 - _3891);
            float _4173 = _3888 / (_3679 - _3891);
            float _4093 = _4158 - _4173;
            if (_4093 <= 0.0f)
            {
                _5798 = 0.0f;
                break;
            }
            float _4227 = _3888 / (max(_3679, _6022) - _3891);
            float2 _4239 = ((float2(int2(_3820 * 0.5f)) / float2(int2(_3820))) * float2(2.0f, -2.0f)) + float2(-1.0f, 1.0f);
            float _4113 = length(_3820);
            _5798 = 1.0f - pow(clamp((((1.3699999726668465882539749145508e-05f * (length(float3((_3897.z * (-1.0f)) * _4227, _3897.w * _4227, _4227)) / length(float3((_3897.z * _4239.x) * _4227, (_3897.w * _4239.y) * _4227, _4227)))) * _4113) * max(_4158, _4173)) / _4093, 0.0f, 1.0f), lerp(1.0f, 3.0f, clamp(_4113 * 0.00045394556946121156215667724609375f, 0.0f, 1.0f)));
            break;
        } while(false);
        float2 _5800;
        _5800 = float2(_5797, _5798);
        float4x4 _4422;
        float4x4 _4555;
        float2 _5947;
        for (int _5799 = 0; _5799 < 4; _5800 = _5947, _5799++)
        {
            int2 _2290 = _2245 + _1648[_5799];
            int2 _2295 = _2250 + _1648[_5799];
            uint2 _4319 = uint2(_2290);
            bool _4323 = all(bool2(_4319.x < _3446.x, _4319.y < _3446.y));
            bool _4330;
            if (_4323)
            {
                _4330 = all(bool2(_4319.x >= uint2(0u, 0u).x, _4319.y >= uint2(0u, 0u).y));
            }
            else
            {
                _4330 = _4323;
            }
            bool _2306;
            if (_4330)
            {
                uint2 _4334 = uint2(_2295);
                bool _4338 = all(bool2(_4334.x < _3461.x, _4334.y < _3461.y));
                bool _4345;
                if (_4338)
                {
                    _4345 = all(bool2(_4334.x >= uint2(0u, 0u).x, _4334.y >= uint2(0u, 0u).y));
                }
                else
                {
                    _4345 = _4338;
                }
                _2306 = _4345;
            }
            else
            {
                _2306 = _4330;
            }
            if (_2306)
            {
                float2 _2313 = (float2(_2290) + 0.5f.xx) / _3419;
                float2 _2319 = (float2(_2295) + 0.5f.xx) / _3424;
                float4 _4351 = r_depth_tm1.Load(int3(_2290, 0));
                float _4352 = _4351.x;
                float4 _4359 = r_depth_tp1.Load(int3(_2295, 0));
                float _4360 = _4359.x;
                float4x4 _5925;
                do
                {
                    bool _5924;
                    do
                    {
                        _4422 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_3575)
                        {
                            _5924 = false;
                            break;
                        }
                        uint _4456 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_4456 + 32u) * 4 + 0) != 1u)
                        {
                            _5924 = false;
                            break;
                        }
                        uint _5921;
                        _5921 = 0u;
                        for (; _5921 < 4u; _5921++)
                        {
                            for (uint _5922 = 0u; _5922 < 4u; )
                            {
                                _4422[_5921][_5922] = asfloat(rw_nfru_diagnostics.Load<uint>((((_4456 + 16u) + (_5921 * 4u)) + _5922) * 4 + 0));
                                _5922++;
                                continue;
                            }
                        }
                        _5924 = true;
                        break;
                    } while(false);
                    if (_5924)
                    {
                        _5925 = _4422;
                        break;
                    }
                    _5925 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _4412 = mul(float4((float2(_2313.x, 1.0f - _2313.y) * 2.0f) - 1.0f.xx, _4352, 1.0f), _5925);
                float _4417 = _4412.z / _4412.w;
                float4x4 _5930;
                do
                {
                    bool _5929;
                    do
                    {
                        _4555 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_3575)
                        {
                            _5929 = false;
                            break;
                        }
                        uint _4589 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_4589 + 32u) * 4 + 0) != 1u)
                        {
                            _5929 = false;
                            break;
                        }
                        uint _5926;
                        _5926 = 0u;
                        for (; _5926 < 4u; _5926++)
                        {
                            for (uint _5927 = 0u; _5927 < 4u; )
                            {
                                _4555[_5926][_5927] = asfloat(rw_nfru_diagnostics.Load<uint>(((_4589 + (_5926 * 4u)) + _5927) * 4 + 0));
                                _5927++;
                                continue;
                            }
                        }
                        _5929 = true;
                        break;
                    } while(false);
                    if (_5929)
                    {
                        _5930 = _4555;
                        break;
                    }
                    _5930 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float4 _4545 = mul(float4((float2(_2319.x, 1.0f - _2319.y) * 2.0f) - 1.0f.xx, _4360, 1.0f), _5930);
                float _4550 = _4545.z / _4545.w;
                float _5931;
                do
                {
                    float _4764 = _3888 / (_4360 - _3891);
                    float _4779 = _3888 / (_4417 - _3891);
                    float _4699 = _4764 - _4779;
                    if (_4699 <= 0.0f)
                    {
                        _5931 = 0.0f;
                        break;
                    }
                    float _4833 = _3888 / (max(_4417, _4360) - _3891);
                    float2 _4845 = ((float2(int2(_3820 * 0.5f)) / float2(int2(_3820))) * float2(2.0f, -2.0f)) + float2(-1.0f, 1.0f);
                    float _4719 = length(_3820);
                    _5931 = 1.0f - pow(clamp((((1.3699999726668465882539749145508e-05f * (length(float3((_3897.z * (-1.0f)) * _4833, _3897.w * _4833, _4833)) / length(float3((_3897.z * _4845.x) * _4833, (_3897.w * _4845.y) * _4833, _4833)))) * _4719) * max(_4764, _4779)) / _4699, 0.0f, 1.0f), lerp(1.0f, 3.0f, clamp(_4719 * 0.00045394556946121156215667724609375f, 0.0f, 1.0f)));
                    break;
                } while(false);
                float _5932;
                do
                {
                    float _5029 = _3888 / (_4352 - _3891);
                    float _5044 = _3888 / (_4550 - _3891);
                    float _4964 = _5029 - _5044;
                    if (_4964 <= 0.0f)
                    {
                        _5932 = 0.0f;
                        break;
                    }
                    float _5098 = _3888 / (max(_4550, _4352) - _3891);
                    float2 _5110 = ((float2(int2(_3820 * 0.5f)) / float2(int2(_3820))) * float2(2.0f, -2.0f)) + float2(-1.0f, 1.0f);
                    float _4984 = length(_3820);
                    _5932 = 1.0f - pow(clamp((((1.3699999726668465882539749145508e-05f * (length(float3((_3897.z * (-1.0f)) * _5098, _3897.w * _5098, _5098)) / length(float3((_3897.z * _5110.x) * _5098, (_3897.w * _5110.y) * _5098, _5098)))) * _4984) * max(_5029, _5044)) / _4964, 0.0f, 1.0f), lerp(1.0f, 3.0f, clamp(_4984 * 0.00045394556946121156215667724609375f, 0.0f, 1.0f)));
                    break;
                } while(false);
                _5947 = max(_5800, float2(_5931, _5932));
            }
            else
            {
                _5947 = _5800;
            }
        }
        float2 _5680 = float2(clamp(_5800.x + _2150, 0.0f, 1.0f), clamp(_5800.y + _2150, 0.0f, 1.0f));
        bool2 _6024 = _2121.xx;
        float4 _5270 = cbFI_QuantParamsSINT.y.xxxx;
        int4 _5274 = int4(clamp(round((float4(_5836, _5859.x) * cbFI_QuantParamsSINT.x) + _5270), (-128.0f).xxxx, 127.0f.xxxx));
        int4 _5291 = int4(clamp(round((float4(_5859.yz, _5882.xy) * cbFI_QuantParamsSINT.x) + _5270), (-128.0f).xxxx, 127.0f.xxxx));
        int4 _5308 = int4(clamp(round((float4(_5882.z, _5905) * cbFI_QuantParamsSINT.x) + _5270), (-128.0f).xxxx, 127.0f.xxxx));
        int4 _5325 = int4(clamp(round((float4(1.0f - (log((_6022 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f), 1.0f - (log((_6023 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f), float2(_6024.x ? 1.0f.xx.x : _5680.x, _6024.y ? 1.0f.xx.y : _5680.y)) * cbFI_QuantParamsSINT.x) + _5270), (-128.0f).xxxx, 127.0f.xxxx));
        uint2 _5255 = uint2(_5682);
        uint _5341 = (_5255.y * uint(cbFI_InputTensorSize.x)) + _5255.x;
        rw_in_tensor.Store<uint>(_5341 * 16 + 0, (((uint(_5274.x) & 255u) | ((uint(_5274.y) & 255u) << 8u)) | ((uint(_5274.z) & 255u) << 16u)) | (uint(_5274.w) << 24u));
        rw_in_tensor.Store<uint>(_5341 * 16 + 4, (((uint(_5291.x) & 255u) | ((uint(_5291.y) & 255u) << 8u)) | ((uint(_5291.z) & 255u) << 16u)) | (uint(_5291.w) << 24u));
        rw_in_tensor.Store<uint>(_5341 * 16 + 8, (((uint(_5308.x) & 255u) | ((uint(_5308.y) & 255u) << 8u)) | ((uint(_5308.z) & 255u) << 16u)) | (uint(_5308.w) << 24u));
        rw_in_tensor.Store<uint>(_5341 * 16 + 12, (((uint(_5325.x) & 255u) | ((uint(_5325.y) & 255u) << 8u)) | ((uint(_5325.z) & 255u) << 16u)) | (uint(_5325.w) << 24u));
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
