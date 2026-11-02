struct InputTensorPacked_t
{
    uint rgbM1MV_rP1MV;
    uint gbP1MV_rgM1OF;
    uint bM1OF_rgbP1OF;
    uint depth_disMask;
};

static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1554[4] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1) };

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
    int2 _1655 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1655.x >= cbFI_InputTensorSize.x, _1655.y >= cbFI_InputTensorSize.y)))
        {
            break;
        }
        int _1834 = _1655.x;
        int2 _5167;
        if (_1834 >= cbFI_FlowLaneSize.x)
        {
            int2 _4983 = _1655;
            _4983.x = (cbFI_FlowLaneSize.x - 1) - (_1834 - cbFI_FlowLaneSize.x);
            _5167 = _4983;
        }
        else
        {
            _5167 = _1655;
        }
        int2 _5168;
        if (_5167.y >= cbFI_FlowLaneSize.y)
        {
            int2 _4990 = _5167;
            _4990.y = (cbFI_FlowLaneSize.y - 1) - (_5167.y - cbFI_FlowLaneSize.y);
            _5168 = _4990;
        }
        else
        {
            _5168 = _5167;
        }
        float2 _1873 = (float2(_5168) + 0.5f.xx) * cbFI_FlowLaneSizeRcp;
        int2 _1879 = int2(floor(_1873 * float2(cbFI_MvDepthLaneSize)));
        int2 _1885 = int2(floor(_1873 * float2(cbFI_FlowLaneSize)));
        float2 _2277 = r_warped_filled_flow_tm1.Load(int3(_1885, 0)).xy;
        float2 _2283 = r_warped_filled_motion_tp1.Load(int3(_1879, 0)).xy;
        bool _2305 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5169;
        if (_2305)
        {
            float _2318 = ((2.0f * _1873.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5169 = float2(atan(_2318) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _1873.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2318 * _2318))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5169 = _1873;
        }
        float2 _5170;
        if (_2305)
        {
            float2 _2393 = clamp((((_5169 + (_2283 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _2396 = tan(_2393.x);
            _5170 = (float2(_2396 / cbFI_DeviceToViewDepth.z, (tan(_2393.y) * sqrt(1.0f + (_2396 * _2396))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _5170 = _5169 + (_2283 * cbFI_Timestep);
        }
        float _1900 = cbFI_Timestep - 1.0f;
        float2 _5171;
        if (_2305)
        {
            float2 _2464 = clamp((((_5169 + (_2283 * _1900)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _2467 = tan(_2464.x);
            _5171 = (float2(_2467 / cbFI_DeviceToViewDepth.z, (tan(_2464.y) * sqrt(1.0f + (_2467 * _2467))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _5171 = _5169 + (_2283 * _1900);
        }
        float _1905 = -cbFI_Timestep;
        float2 _5172;
        if (_2305)
        {
            float2 _2535 = clamp((((_5169 + (_2277 * _1905)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _2538 = tan(_2535.x);
            _5172 = (float2(_2538 / cbFI_DeviceToViewDepth.z, (tan(_2535.y) * sqrt(1.0f + (_2538 * _2538))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _5172 = _5169 + (_2277 * _1905);
        }
        float _1910 = 1.0f - cbFI_Timestep;
        float2 _5173;
        if (_2305)
        {
            float2 _2606 = clamp((((_5169 + (_2277 * _1910)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _2609 = tan(_2606.x);
            _5173 = (float2(_2609 / cbFI_DeviceToViewDepth.z, (tan(_2606.y) * sqrt(1.0f + (_2609 * _2609))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _5173 = _5169 + (_2277 * _1910);
        }
        bool _1915 = _5171.x <= 0.0f;
        bool _1922;
        if (!_1915)
        {
            _1922 = _5171.x >= 1.0f;
        }
        else
        {
            _1922 = _1915;
        }
        bool _1936;
        if (!_1922)
        {
            bool _1927 = _5171.y <= 0.0f;
            bool _1934;
            if (!_1927)
            {
                _1934 = _5171.y >= 1.0f;
            }
            else
            {
                _1934 = _1927;
            }
            _1936 = _1934;
        }
        else
        {
            _1936 = _1922;
        }
        bool _1939 = _5170.x <= 0.0f;
        bool _1946;
        if (!_1939)
        {
            _1946 = _5170.x >= 1.0f;
        }
        else
        {
            _1946 = _1939;
        }
        bool _1960;
        if (!_1946)
        {
            bool _1951 = _5170.y <= 0.0f;
            bool _1958;
            if (!_1951)
            {
                _1958 = _5170.y >= 1.0f;
            }
            else
            {
                _1958 = _1951;
            }
            _1960 = _1958;
        }
        else
        {
            _1960 = _1946;
        }
        bool _1963 = _5172.x <= 0.0f;
        bool _1970;
        if (!_1963)
        {
            _1970 = _5172.x >= 1.0f;
        }
        else
        {
            _1970 = _1963;
        }
        bool _1984;
        if (!_1970)
        {
            bool _1975 = _5172.y <= 0.0f;
            bool _1982;
            if (!_1975)
            {
                _1982 = _5172.y >= 1.0f;
            }
            else
            {
                _1982 = _1975;
            }
            _1984 = _1982;
        }
        else
        {
            _1984 = _1970;
        }
        bool _1987 = _5173.x <= 0.0f;
        bool _1994;
        if (!_1987)
        {
            _1994 = _5173.x >= 1.0f;
        }
        else
        {
            _1994 = _1987;
        }
        bool _2008;
        if (!_1994)
        {
            bool _1999 = _5173.y <= 0.0f;
            bool _2006;
            if (!_1999)
            {
                _2006 = _5173.y >= 1.0f;
            }
            else
            {
                _2006 = _1999;
            }
            _2008 = _2006;
        }
        else
        {
            _2008 = _1994;
        }
        bool _2641 = !((cbFI_pad0 & 1024u) != 0u);
        bool _2642 = !_2641;
        bool _2659;
        if (_2642)
        {
            _2659 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_1879.y * cbFI_MvDepthLaneSize.x) + _1879.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _2659 = _2641;
        }
        bool _2691;
        if (_2642)
        {
            _2691 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_1885.y * cbFI_FlowLaneSize.x) + _1885.x)) * 4 + 0) != 0u;
        }
        else
        {
            _2691 = _2641;
        }
        bool _2014 = !_2659;
        if (_2014)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2727;
                rw_nfru_diagnostics.InterlockedAdd(240, 1u, _2727);
            }
        }
        bool _5396 = _2014 ? true : _1960;
        bool _5397 = _2014 ? true : _1936;
        bool _2019 = !_2691;
        if (_2019)
        {
            if ((cbFI_pad0 & 512u) != 0u)
            {
                uint _2737;
                rw_nfru_diagnostics.InterlockedAdd(244, 1u, _2737);
            }
        }
        bool _5398 = _2019 ? true : _2008;
        bool _5399 = _2019 ? true : _1984;
        uint _2745_dummy_parameter;
        float _2030 = 1.0f - float(_5397);
        float _2043 = float(((r_mv_holes_tp1.Load(int3(_1879, 0)).x * _2030) - (float(r_mv_holes_tm1.Load(int3(int2(floor(_5170 * float2(int2(spvTextureSize(r_mv_holes_tm1, uint(0), _2745_dummy_parameter))))), 0)).x != 0.0f) * _2030)) < 0.0f);
        float3 _5304;
        if (!_5396)
        {
            _5304 = r_previous_interpolation_source.Load(int3(int2(_5170 * float2(cbFI_DisplaySize)), 0)).xyz;
        }
        else
        {
            _5304 = 0.0f.xxx;
        }
        float3 _5319;
        if (!_5397)
        {
            _5319 = r_current_interpolation_source.Load(int3(int2(_5171 * float2(cbFI_DisplaySize)), 0)).xyz;
        }
        else
        {
            _5319 = 0.0f.xxx;
        }
        float3 _5334;
        if (!_5399)
        {
            _5334 = r_previous_interpolation_source.Load(int3(int2(_5172 * float2(cbFI_DisplaySize)), 0)).xyz;
        }
        else
        {
            _5334 = 0.0f.xxx;
        }
        float3 _5349;
        if (!_5398)
        {
            _5349 = r_current_interpolation_source.Load(int3(int2(_5173 * float2(cbFI_DisplaySize)), 0)).xyz;
        }
        else
        {
            _5349 = 0.0f.xxx;
        }
        uint _2091 = (uint(_5168.x) * 10000u) + uint(_5168.y);
        float3 _5300;
        if (_5396)
        {
            uint _2814 = _2091 + cbFI_RandomSeed;
            uint _2834 = ((_2814 ^ 61u) ^ (_2814 >> uint(16))) * 9u;
            uint _2840 = (_2834 ^ (_2834 >> uint(4))) * 668265261u;
            uint _2856 = (_2091 + 2654435769u) + cbFI_RandomSeed;
            uint _2876 = ((_2856 ^ 61u) ^ (_2856 >> uint(16))) * 9u;
            uint _2882 = (_2876 ^ (_2876 >> uint(4))) * 668265261u;
            uint _2898 = (_2091 + 1013904242u) + cbFI_RandomSeed;
            uint _2918 = ((_2898 ^ 61u) ^ (_2898 >> uint(16))) * 9u;
            uint _2924 = (_2918 ^ (_2918 >> uint(4))) * 668265261u;
            _5300 = float3(asfloat(((_2840 ^ (_2840 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_2882 ^ (_2882 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_2924 ^ (_2924 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f);
        }
        else
        {
            _5300 = _5304;
        }
        float3 _5315;
        if (_5397)
        {
            uint _2940 = (_2091 + 3668340011u) + cbFI_RandomSeed;
            uint _2960 = ((_2940 ^ 61u) ^ (_2940 >> uint(16))) * 9u;
            uint _2966 = (_2960 ^ (_2960 >> uint(4))) * 668265261u;
            uint _2982 = (_2091 + 2027808484u) + cbFI_RandomSeed;
            uint _3002 = ((_2982 ^ 61u) ^ (_2982 >> uint(16))) * 9u;
            uint _3008 = (_3002 ^ (_3002 >> uint(4))) * 668265261u;
            uint _3024 = (_2091 + 387276957u) + cbFI_RandomSeed;
            uint _3044 = ((_3024 ^ 61u) ^ (_3024 >> uint(16))) * 9u;
            uint _3050 = (_3044 ^ (_3044 >> uint(4))) * 668265261u;
            _5315 = float3(asfloat(((_2966 ^ (_2966 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3008 ^ (_3008 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3050 ^ (_3050 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f);
        }
        else
        {
            _5315 = _5319;
        }
        float3 _5330;
        if (_5399)
        {
            uint _3066 = (_2091 + 3041712726u) + cbFI_RandomSeed;
            uint _3086 = ((_3066 ^ 61u) ^ (_3066 >> uint(16))) * 9u;
            uint _3092 = (_3086 ^ (_3086 >> uint(4))) * 668265261u;
            uint _3108 = (_2091 + 1401181199u) + cbFI_RandomSeed;
            uint _3128 = ((_3108 ^ 61u) ^ (_3108 >> uint(16))) * 9u;
            uint _3134 = (_3128 ^ (_3128 >> uint(4))) * 668265261u;
            uint _3150 = (_2091 + 4055616968u) + cbFI_RandomSeed;
            uint _3170 = ((_3150 ^ 61u) ^ (_3150 >> uint(16))) * 9u;
            uint _3176 = (_3170 ^ (_3170 >> uint(4))) * 668265261u;
            _5330 = float3(asfloat(((_3092 ^ (_3092 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3134 ^ (_3134 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3176 ^ (_3176 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f);
        }
        else
        {
            _5330 = _5334;
        }
        float3 _5345;
        if (_5398)
        {
            uint _3192 = (_2091 + 2415085441u) + cbFI_RandomSeed;
            uint _3212 = ((_3192 ^ 61u) ^ (_3192 >> uint(16))) * 9u;
            uint _3218 = (_3212 ^ (_3212 >> uint(4))) * 668265261u;
            uint _3234 = (_2091 + 774553914u) + cbFI_RandomSeed;
            uint _3254 = ((_3234 ^ 61u) ^ (_3234 >> uint(16))) * 9u;
            uint _3260 = (_3254 ^ (_3254 >> uint(4))) * 668265261u;
            uint _3276 = (_2091 + 3428989683u) + cbFI_RandomSeed;
            uint _3296 = ((_3276 ^ 61u) ^ (_3276 >> uint(16))) * 9u;
            uint _3302 = (_3296 ^ (_3296 >> uint(4))) * 668265261u;
            _5345 = float3(asfloat(((_3218 ^ (_3218 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3260 ^ (_3260 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f, asfloat(((_3302 ^ (_3302 >> uint(15))) >> uint(9)) | 1065353216u) - 1.0f);
        }
        else
        {
            _5345 = _5349;
        }
        uint _3311_dummy_parameter;
        float2 _3312 = float2(int2(spvTextureSize(r_depth_tm1, uint(0), _3311_dummy_parameter)));
        uint _3316_dummy_parameter;
        float2 _3317 = float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3316_dummy_parameter)));
        int2 _2138 = int2(floor(_5170 * _3312));
        int2 _2143 = int2(floor(_5171 * _3317));
        uint2 _3337 = uint2(_2138);
        uint2 _3339 = uint2(int2(_3312));
        bool _3341 = all(bool2(_3337.x < _3339.x, _3337.y < _3339.y));
        bool _3348;
        if (_3341)
        {
            _3348 = all(bool2(_3337.x >= uint2(0u, 0u).x, _3337.y >= uint2(0u, 0u).y));
        }
        else
        {
            _3348 = _3341;
        }
        float _5400 = (!_3348) ? 0.0f : r_depth_tm1.Load(int3(_2138, 0)).x;
        uint2 _3352 = uint2(_2143);
        uint2 _3354 = uint2(int2(_3317));
        bool _3356 = all(bool2(_3352.x < _3354.x, _3352.y < _3354.y));
        bool _3363;
        if (_3356)
        {
            _3363 = all(bool2(_3352.x >= uint2(0u, 0u).x, _3352.y >= uint2(0u, 0u).y));
        }
        else
        {
            _3363 = _3356;
        }
        float2 _3510;
        float _3578;
        float _3581;
        float4 _3587;
        float _5401 = (!_3363) ? 0.0f : r_depth_tp1.Load(int3(_2143, 0)).x;
        float4 _3434 = mul(float4((float2(_5170.x, 1.0f - _5170.y) * 2.0f) - 1.0f.xx, _5400, 1.0f), cbFI_MotionTM1ToTP1);
        float _3439 = _3434.z / _3434.w;
        float4 _3466 = mul(float4((float2(_5171.x, 1.0f - _5171.y) * 2.0f) - 1.0f.xx, _5401, 1.0f), cbFI_MotionTP1ToTM1);
        float _3471 = _3466.z / _3466.w;
        float _5273;
        do
        {
            _3510 = float2(cbFI_RenderSize);
            _3587 = cbFI_DeviceToViewDepth;
            _3578 = _3587.y;
            _3581 = _3587.x;
            float _3583 = _3578 / (_5401 - _3581);
            float _3598 = _3578 / (_3439 - _3581);
            float _3518 = _3583 - _3598;
            if (_3518 <= 0.0f)
            {
                _5273 = 0.0f;
                break;
            }
            float _3652 = _3578 / (max(_3439, _5401) - _3581);
            float2 _3664 = ((float2(int2(_3510 * 0.5f)) / float2(int2(_3510))) * float2(2.0f, -2.0f)) + float2(-1.0f, 1.0f);
            float _3538 = length(_3510);
            _5273 = 1.0f - pow(clamp((((1.3699999726668465882539749145508e-05f * (length(float3((_3587.z * (-1.0f)) * _3652, _3587.w * _3652, _3652)) / length(float3((_3587.z * _3664.x) * _3652, (_3587.w * _3664.y) * _3652, _3652)))) * _3538) * max(_3583, _3598)) / _3518, 0.0f, 1.0f), lerp(1.0f, 3.0f, clamp(_3538 * 0.00045394556946121156215667724609375f, 0.0f, 1.0f)));
            break;
        } while(false);
        float _5274;
        do
        {
            float _3848 = _3578 / (_5400 - _3581);
            float _3863 = _3578 / (_3471 - _3581);
            float _3783 = _3848 - _3863;
            if (_3783 <= 0.0f)
            {
                _5274 = 0.0f;
                break;
            }
            float _3917 = _3578 / (max(_3471, _5400) - _3581);
            float2 _3929 = ((float2(int2(_3510 * 0.5f)) / float2(int2(_3510))) * float2(2.0f, -2.0f)) + float2(-1.0f, 1.0f);
            float _3803 = length(_3510);
            _5274 = 1.0f - pow(clamp((((1.3699999726668465882539749145508e-05f * (length(float3((_3587.z * (-1.0f)) * _3917, _3587.w * _3917, _3917)) / length(float3((_3587.z * _3929.x) * _3917, (_3587.w * _3929.y) * _3917, _3917)))) * _3803) * max(_3848, _3863)) / _3783, 0.0f, 1.0f), lerp(1.0f, 3.0f, clamp(_3803 * 0.00045394556946121156215667724609375f, 0.0f, 1.0f)));
            break;
        } while(false);
        float2 _5276;
        _5276 = float2(_5273, _5274);
        float2 _5365;
        for (int _5275 = 0; _5275 < 4; _5276 = _5365, _5275++)
        {
            int2 _2183 = _2138 + _1554[_5275];
            int2 _2188 = _2143 + _1554[_5275];
            uint2 _4009 = uint2(_2183);
            bool _4013 = all(bool2(_4009.x < _3339.x, _4009.y < _3339.y));
            bool _4020;
            if (_4013)
            {
                _4020 = all(bool2(_4009.x >= uint2(0u, 0u).x, _4009.y >= uint2(0u, 0u).y));
            }
            else
            {
                _4020 = _4013;
            }
            bool _2199;
            if (_4020)
            {
                uint2 _4024 = uint2(_2188);
                bool _4028 = all(bool2(_4024.x < _3354.x, _4024.y < _3354.y));
                bool _4035;
                if (_4028)
                {
                    _4035 = all(bool2(_4024.x >= uint2(0u, 0u).x, _4024.y >= uint2(0u, 0u).y));
                }
                else
                {
                    _4035 = _4028;
                }
                _2199 = _4035;
            }
            else
            {
                _2199 = _4020;
            }
            if (_2199)
            {
                float2 _2206 = (float2(_2183) + 0.5f.xx) / _3312;
                float2 _2212 = (float2(_2188) + 0.5f.xx) / _3317;
                float4 _4041 = r_depth_tm1.Load(int3(_2183, 0));
                float _4042 = _4041.x;
                float4 _4049 = r_depth_tp1.Load(int3(_2188, 0));
                float _4050 = _4049.x;
                float4 _4102 = mul(float4((float2(_2206.x, 1.0f - _2206.y) * 2.0f) - 1.0f.xx, _4042, 1.0f), cbFI_MotionTM1ToTP1);
                float _4107 = _4102.z / _4102.w;
                float4 _4133 = mul(float4((float2(_2212.x, 1.0f - _2212.y) * 2.0f) - 1.0f.xx, _4050, 1.0f), cbFI_MotionTP1ToTM1);
                float _4138 = _4133.z / _4133.w;
                float _5357;
                do
                {
                    float _4250 = _3578 / (_4050 - _3581);
                    float _4265 = _3578 / (_4107 - _3581);
                    float _4185 = _4250 - _4265;
                    if (_4185 <= 0.0f)
                    {
                        _5357 = 0.0f;
                        break;
                    }
                    float _4319 = _3578 / (max(_4107, _4050) - _3581);
                    float2 _4331 = ((float2(int2(_3510 * 0.5f)) / float2(int2(_3510))) * float2(2.0f, -2.0f)) + float2(-1.0f, 1.0f);
                    float _4205 = length(_3510);
                    _5357 = 1.0f - pow(clamp((((1.3699999726668465882539749145508e-05f * (length(float3((_3587.z * (-1.0f)) * _4319, _3587.w * _4319, _4319)) / length(float3((_3587.z * _4331.x) * _4319, (_3587.w * _4331.y) * _4319, _4319)))) * _4205) * max(_4250, _4265)) / _4185, 0.0f, 1.0f), lerp(1.0f, 3.0f, clamp(_4205 * 0.00045394556946121156215667724609375f, 0.0f, 1.0f)));
                    break;
                } while(false);
                float _5358;
                do
                {
                    float _4515 = _3578 / (_4042 - _3581);
                    float _4530 = _3578 / (_4138 - _3581);
                    float _4450 = _4515 - _4530;
                    if (_4450 <= 0.0f)
                    {
                        _5358 = 0.0f;
                        break;
                    }
                    float _4584 = _3578 / (max(_4138, _4042) - _3581);
                    float2 _4596 = ((float2(int2(_3510 * 0.5f)) / float2(int2(_3510))) * float2(2.0f, -2.0f)) + float2(-1.0f, 1.0f);
                    float _4470 = length(_3510);
                    _5358 = 1.0f - pow(clamp((((1.3699999726668465882539749145508e-05f * (length(float3((_3587.z * (-1.0f)) * _4584, _3587.w * _4584, _4584)) / length(float3((_3587.z * _4596.x) * _4584, (_3587.w * _4596.y) * _4584, _4584)))) * _4470) * max(_4515, _4530)) / _4450, 0.0f, 1.0f), lerp(1.0f, 3.0f, clamp(_4470 * 0.00045394556946121156215667724609375f, 0.0f, 1.0f)));
                    break;
                } while(false);
                _5365 = max(_5276, float2(_5357, _5358));
            }
            else
            {
                _5365 = _5276;
            }
        }
        float2 _5166 = float2(clamp(_5276.x + _2043, 0.0f, 1.0f), clamp(_5276.y + _2043, 0.0f, 1.0f));
        bool2 _5402 = _2014.xx;
        float4 _4756 = cbFI_QuantParamsSINT.y.xxxx;
        int4 _4760 = int4(clamp(round((float4(_5300, _5315.x) * cbFI_QuantParamsSINT.x) + _4756), (-128.0f).xxxx, 127.0f.xxxx));
        int4 _4777 = int4(clamp(round((float4(_5315.yz, _5330.xy) * cbFI_QuantParamsSINT.x) + _4756), (-128.0f).xxxx, 127.0f.xxxx));
        int4 _4794 = int4(clamp(round((float4(_5330.z, _5345) * cbFI_QuantParamsSINT.x) + _4756), (-128.0f).xxxx, 127.0f.xxxx));
        int4 _4811 = int4(clamp(round((float4(1.0f - (log(((_5400 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f), 1.0f - (log(((_5401 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f), float2(_5402.x ? 1.0f.xx.x : _5166.x, _5402.y ? 1.0f.xx.y : _5166.y)) * cbFI_QuantParamsSINT.x) + _4756), (-128.0f).xxxx, 127.0f.xxxx));
        uint2 _4741 = uint2(_5168);
        uint _4827 = (_4741.y * uint(cbFI_InputTensorSize.x)) + _4741.x;
        rw_in_tensor.Store<uint>(_4827 * 16 + 0, (((uint(_4760.x) & 255u) | ((uint(_4760.y) & 255u) << 8u)) | ((uint(_4760.z) & 255u) << 16u)) | (uint(_4760.w) << 24u));
        rw_in_tensor.Store<uint>(_4827 * 16 + 4, (((uint(_4777.x) & 255u) | ((uint(_4777.y) & 255u) << 8u)) | ((uint(_4777.z) & 255u) << 16u)) | (uint(_4777.w) << 24u));
        rw_in_tensor.Store<uint>(_4827 * 16 + 8, (((uint(_4794.x) & 255u) | ((uint(_4794.y) & 255u) << 8u)) | ((uint(_4794.z) & 255u) << 16u)) | (uint(_4794.w) << 24u));
        rw_in_tensor.Store<uint>(_4827 * 16 + 12, (((uint(_4811.x) & 255u) | ((uint(_4811.y) & 255u) << 8u)) | ((uint(_4811.z) & 255u) << 16u)) | (uint(_4811.w) << 24u));
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
