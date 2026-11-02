static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1322[3] = { int2(1, 0), int2(0, 1), int2(1, 1) };
static const int2 _1536[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

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

RWByteAddressBuffer rw_nfru_diagnostics : register(u10, space0);
Texture2D<float4> r_motion_tp1 : register(t0, space0);
Texture2D<float4> r_depth_tp1 : register(t1, space0);
Texture2D<float4> r_depth_tm1 : register(t2, space0);
Texture2D<float4> r_dynamic_mask_tm1 : register(t3, space0);
RWTexture2D<float> rw_depth_tm1_next : register(u8, space0);
RWTexture2D<unorm float> rw_dynamic_mask_tp1 : register(u4, space0);
RWTexture2D<uint> rw_warped_motion_qdata_tp1 : register(u5, space0);
RWTexture2D<unorm float> rw_mv_holes_tp1 : register(u6, space0);
RWTexture2D<unorm float> rw_mv_holes_tm1 : register(u7, space0);

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
    int2 _1933 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1933.x >= cbFI_MvDepthLaneSize.x, _1933.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2218 = _1933.x + (_1933.y * cbFI_MvDepthLaneSize.x);
        float _2225 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2227 = float2(_1933);
        float2 _2231 = (_2227 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2703 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5261;
        if (_2703)
        {
            float _2716 = ((2.0f * _2231.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5261 = float2(atan(_2716) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2231.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2716 * _2716))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5261 = _2231;
        }
        uint _2758_dummy_parameter;
        float4 _2765 = r_depth_tp1.Load(int3(int2(floor(_2231 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2758_dummy_parameter))))), 0));
        float _2766 = _2765.x;
        uint _2774_dummy_parameter;
        float4 _2781 = r_depth_tp1.Load(int3(int2(floor(_2231 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2774_dummy_parameter))))), 0));
        float _2782 = _2781.x;
        rw_depth_tm1_next[_1933] = float4(_2766, 0.0f, 0.0f, 0.0f).x;
        float2 _2806 = float2(_2231.x, 1.0f - _2231.y);
        float2 _2810 = (_2806 * 2.0f) - 1.0f.xx;
        float _2812 = _2810.x;
        float4 _2817 = mul(float4(_2812, _2810.y, _2766, 1.0f), cbFI_MotionTP1ToTM1);
        float _2819 = _2817.w;
        float _2821 = float(_2819 < 0.0f);
        float2 _2833 = _2806 - (((_2817.xy / _2819.xx) + 1.0f.xx) * 0.5f);
        float2 _2835 = abs(_2833);
        bool2 _2841 = all(bool2(_2835.x < 9.9999997473787516355514526367188e-06f.xx.x, _2835.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2842 = float2(_2841.x ? 0.0f.xx.x : _2833.x, _2841.y ? 0.0f.xx.y : _2833.y);
        bool2 _2847 = any(isnan(_2842)).xx;
        float2 _2848 = float2(_2847.x ? 0.0f.xx.x : _2842.x, _2847.y ? 0.0f.xx.y : _2842.y);
        bool2 _2853 = any(isinf(_2848)).xx;
        float2 _2854 = float2(_2853.x ? 0.0f.xx.x : _2848.x, _2853.y ? 0.0f.xx.y : _2848.y);
        float _2892 = 1.0f - (log(((_2766 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5262;
        if (_2892 == 1.0f)
        {
            _5262 = _2892 + ((float(_2218) * _2225) * 0.100000001490116119384765625f);
        }
        else
        {
            _5262 = _2892;
        }
        float _2882 = 1.10000002384185791015625f - _5262;
        uint _2899_dummy_parameter;
        float2 _2914 = r_motion_tp1.Load(int3(int2(floor(_2231 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2899_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _2924 = (cbFI_pad0 & 512u) != 0u;
        if (_2924)
        {
            uint _2928;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _2928);
        }
        bool _2941;
        float _2255 = 1.0f - cbFI_Timestep;
        float2 _5263;
        float2 _5264;
        do
        {
            _2941 = !_2703;
            if (_2941)
            {
                _5264 = _2914;
                _5263 = _2914;
                break;
            }
            float2 _2948 = _2231 + _2914;
            float _2984 = ((2.0f * _2948.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _2951 = (float2(atan(_2984) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2948.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2984 * _2984))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5261;
            float2 _3033 = clamp((((_5261 + (_2951 * _2255)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3036 = tan(_3033.x);
            _5264 = _2951;
            _5263 = (((float2(_3036 / cbFI_DeviceToViewDepth.z, (tan(_3033.y) * sqrt(1.0f + (_3036 * _3036))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2231) / max(_2255, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _3082;
        bool _5267;
        int2 _5268;
        uint _5276;
        do
        {
            _3082 = float2(cbFI_MvDepthLaneSize);
            float2 _3083 = _5263 * _3082;
            float2 _3087 = _5264 * _3082;
            bool _3090 = any(isnan(_3083));
            bool _3097;
            if (!_3090)
            {
                _3097 = any(isinf(_3083));
            }
            else
            {
                _3097 = _3090;
            }
            bool _3104;
            if (!_3097)
            {
                _3104 = any(isnan(_3087));
            }
            else
            {
                _3104 = _3097;
            }
            bool _3111;
            if (!_3104)
            {
                _3111 = any(isinf(_3087));
            }
            else
            {
                _3111 = _3104;
            }
            bool _3117;
            if (!_3111)
            {
                _3117 = isnan(_2882);
            }
            else
            {
                _3117 = _3111;
            }
            bool _3123;
            if (!_3117)
            {
                _3123 = isinf(_2882);
            }
            else
            {
                _3123 = _3117;
            }
            if (_3123)
            {
                _5276 = 0u;
                _5268 = int2(0, 0);
                _5267 = false;
                break;
            }
            float2 _3128 = _3083 * _2255;
            bool _3131 = any(isnan(_3128));
            bool _3138;
            if (!_3131)
            {
                _3138 = any(isinf(_3128));
            }
            else
            {
                _3138 = _3131;
            }
            if (_3138)
            {
                _5276 = 0u;
                _5268 = int2(0, 0);
                _5267 = false;
                break;
            }
            float2 _3145 = _2227 + floor(_3128);
            bool _3148 = any(bool2(_3145.x < 0.0f.xx.x, _3145.y < 0.0f.xx.y));
            bool _3157;
            if (!_3148)
            {
                _3157 = any(bool2(_3145.x >= _3082.x, _3145.y >= _3082.y));
            }
            else
            {
                _3157 = _3148;
            }
            if (_3157)
            {
                _5276 = 0u;
                _5268 = int2(0, 0);
                _5267 = false;
                break;
            }
            float2 _3164 = _3087 * 1.0f;
            float _3211 = _3164.x * 16.0146636962890625f;
            int _3219 = int(clamp(sign(_3211) * ceil(abs(_3211)), -16383.0f, 16383.0f));
            float _3223 = _3164.y * 16.0146636962890625f;
            int _3231 = int(clamp(sign(_3223) * ceil(abs(_3223)), -16383.0f, 16383.0f));
            int _3238 = abs(_3219);
            int _3240 = abs(_3231);
            int _3244 = clamp(firstbithigh(max(_3238, _3240)), 0, 15);
            int _3247 = max((_3244 - 6), 0);
            _5276 = (((((uint((int(round(_2882 * 1860.9090576171875f)) & 2047) << 20) | uint((_3244 & 15) << 16)) | uint(int(_3219 < 0) << 15)) | uint(int(_3231 < 0) << 14)) | uint((clamp(_3238 >> _3247, 0, 127) & 127) << 7)) | uint(clamp(_3240 >> _3247, 0, 127) & 127)) & 2147483647u;
            _5268 = int2(_3145);
            _5267 = true;
            break;
        } while(false);
        if (_5267)
        {
            if (_2924)
            {
                uint _3333;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3333);
            }
            uint _3339;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5268], _5276, _3339);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5286 = 0; _5286 < 3; _5286++)
                {
                    int2 _2290 = _5268 + _1322[_5286];
                    if (all(bool2(_2290.x < cbFI_MvDepthLaneSize.x, _2290.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3344;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2290], _5276, _3344);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2312 = _2231 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2317 = _2231 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2322 = _2312.x < 1.0f;
                bool _2329;
                if (_2322)
                {
                    uint _3365_dummy_parameter;
                    float4 _3372 = r_depth_tp1.Load(int3(int2(floor(_2312 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3365_dummy_parameter))))), 0));
                    float _3373 = _3372.x;
                    _2329 = abs(_2782 - _3373) <= ((0.0500000007450580596923828125f * max(abs(_2782), abs(_3373))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2329 = _2322;
                }
                bool _2332 = _2317.y < 1.0f;
                bool _2339;
                if (_2332)
                {
                    uint _3395_dummy_parameter;
                    float4 _3402 = r_depth_tp1.Load(int3(int2(floor(_2317 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3395_dummy_parameter))))), 0));
                    float _3403 = _3402.x;
                    _2339 = abs(_2782 - _3403) <= ((0.0500000007450580596923828125f * max(abs(_2782), abs(_3403))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2339 = _2332;
                }
                float2 _3428 = (_2231 + (_2914 * _2255)) * _3082;
                uint _3435_dummy_parameter;
                uint _3472_dummy_parameter;
                float2 _5287;
                if (_2329)
                {
                    _5287 = ((_2312 + ((r_motion_tp1.Load(int3(int2(floor(_2312 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3435_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2255)) * _3082) - _3428;
                }
                else
                {
                    _5287 = float2(1.0f, 0.0f);
                }
                float2 _5288;
                if (_2339)
                {
                    _5288 = ((_2317 + ((r_motion_tp1.Load(int3(int2(floor(_2317 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3472_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2255)) * _3082) - _3428;
                }
                else
                {
                    _5288 = float2(0.0f, 1.0f);
                }
                bool _3528 = any(isnan(_5287));
                bool _3535;
                if (!_3528)
                {
                    _3535 = any(isinf(_5287));
                }
                else
                {
                    _3535 = _3528;
                }
                bool2 _5417 = _3535.xx;
                float2 _5418 = float2(_5417.x ? float2(1.0f, 0.0f).x : _5287.x, _5417.y ? float2(1.0f, 0.0f).y : _5287.y);
                bool _3540 = any(isnan(_5288));
                bool _3547;
                if (!_3540)
                {
                    _3547 = any(isinf(_5288));
                }
                else
                {
                    _3547 = _3540;
                }
                bool2 _5419 = _3547.xx;
                float2 _5420 = float2(_5419.x ? float2(0.0f, 1.0f).x : _5288.x, _5419.y ? float2(0.0f, 1.0f).y : _5288.y);
                int2 _3563 = int2(clamp(floor(min(0.0f.xx, _5418) + min(0.0f.xx, _5420)), (-3.0f).xx, 0.0f.xx));
                int2 _3569 = int2(clamp(ceil(max(0.0f.xx, _5418) + max(0.0f.xx, _5420)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3577 = _3563.y;
                for (int _5318 = _3577; _5318 <= _3569.y; _5318++)
                {
                    int _3586 = _3563.x;
                    for (int _5399 = _3586; _5399 <= _3569.x; _5399++)
                    {
                        if ((_5399 == 0) && (_5318 == 0))
                        {
                            continue;
                        }
                        int2 _3605 = _5268 + int2(_5399, _5318);
                        bool _3608 = all(bool2(_3605.x >= int2(0, 0).x, _3605.y >= int2(0, 0).y));
                        bool _3615;
                        if (_3608)
                        {
                            _3615 = all(bool2(_3605.x < cbFI_MvDepthLaneSize.x, _3605.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3615 = _3608;
                        }
                        if (_3615)
                        {
                            uint _3633;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3605], _5276, _3633);
                        }
                    }
                }
            }
        }
        else
        {
            if (_2924)
            {
                uint _3642;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3642);
            }
        }
        uint _3651_dummy_parameter;
        int2 _3651 = int2(spvTextureSize(r_depth_tp1, uint(0), _3651_dummy_parameter));
        float _2059[9];
        _2059[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2231 * float2(_3651))), int2(0, 0), _3651 - int2(1, 1)), 0)).x;
        uint _3676_dummy_parameter;
        int2 _3676 = int2(spvTextureSize(r_depth_tp1, uint(0), _3676_dummy_parameter));
        _2059[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2231 * float2(_3676))) + int2(1, 0), int2(0, 0), _3676 - int2(1, 1)), 0)).x;
        uint _3701_dummy_parameter;
        int2 _3701 = int2(spvTextureSize(r_depth_tp1, uint(0), _3701_dummy_parameter));
        _2059[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2231 * float2(_3701))) + int2(0, 1), int2(0, 0), _3701 - int2(1, 1)), 0)).x;
        uint _3726_dummy_parameter;
        int2 _3726 = int2(spvTextureSize(r_depth_tp1, uint(0), _3726_dummy_parameter));
        _2059[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2231 * float2(_3726))) + int2(0, -1), int2(0, 0), _3726 - int2(1, 1)), 0)).x;
        uint _3751_dummy_parameter;
        int2 _3751 = int2(spvTextureSize(r_depth_tp1, uint(0), _3751_dummy_parameter));
        _2059[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2231 * float2(_3751))) + int2(-1, 0), int2(0, 0), _3751 - int2(1, 1)), 0)).x;
        uint _3776_dummy_parameter;
        int2 _3776 = int2(spvTextureSize(r_depth_tp1, uint(0), _3776_dummy_parameter));
        _2059[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2231 * float2(_3776))) + int2(-1, 1), int2(0, 0), _3776 - int2(1, 1)), 0)).x;
        uint _3801_dummy_parameter;
        int2 _3801 = int2(spvTextureSize(r_depth_tp1, uint(0), _3801_dummy_parameter));
        _2059[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2231 * float2(_3801))) + int2(1, 1), int2(0, 0), _3801 - int2(1, 1)), 0)).x;
        uint _3826_dummy_parameter;
        int2 _3826 = int2(spvTextureSize(r_depth_tp1, uint(0), _3826_dummy_parameter));
        _2059[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2231 * float2(_3826))) + int2(-1, -1), int2(0, 0), _3826 - int2(1, 1)), 0)).x;
        uint _3851_dummy_parameter;
        int2 _3851 = int2(spvTextureSize(r_depth_tp1, uint(0), _3851_dummy_parameter));
        _2059[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2231 * float2(_3851))) + int2(1, -1), int2(0, 0), _3851 - int2(1, 1)), 0)).x;
        int _5320;
        _5320 = 0;
        float _5421;
        int _5422;
        int _5319 = 1;
        float _5397 = _2059[0];
        for (; _5319 < 9; _5397 = _5421, _5320 = _5422, _5319++)
        {
            bool _2412 = _2059[_5319] < _5397;
            _5421 = _2412 ? _2059[_5319] : _5397;
            _5422 = _2412 ? _5319 : _5320;
        }
        uint _3876_dummy_parameter;
        int2 _3876 = int2(spvTextureSize(r_motion_tp1, uint(0), _3876_dummy_parameter));
        float2 _3894 = r_motion_tp1.Load(int3(clamp(int2(floor(_2231 * float2(_3876))) + _1536[_5320], int2(0, 0), _3876 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5321;
        do
        {
            if (_2941)
            {
                _5321 = _3894;
                break;
            }
            float2 _3918 = _2231 + _3894;
            float _3954 = ((2.0f * _3918.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4003 = clamp((((_5261 + (((float2(atan(_3954) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3918.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3954 * _3954))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5261) * _2255)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4006 = tan(_4003.x);
            _5321 = (((float2(_4006 / cbFI_DeviceToViewDepth.z, (tan(_4003.y) * sqrt(1.0f + (_4006 * _4006))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2231) / max(_2255, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        rw_mv_holes_tp1[_1933 + int2(floor((_5321 * _3082) * _2255))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1933 + int2(floor(_3894 * _3082))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4076_dummy_parameter;
        float4 _4083 = r_depth_tm1.Load(int3(int2(floor(_2231 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4076_dummy_parameter))))), 0));
        float _4084 = _4083.x;
        float4 _4114 = mul(float4(_2812, _2810.y, _4084, 1.0f), cbFI_MotionTM1ToTP1);
        float _4116 = _4114.w;
        float2 _4130 = _2806 - (((_4114.xy / _4116.xx) + 1.0f.xx) * 0.5f);
        float2 _4132 = abs(_4130);
        bool2 _4138 = all(bool2(_4132.x < 9.9999997473787516355514526367188e-06f.xx.x, _4132.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4139 = float2(_4138.x ? 0.0f.xx.x : _4130.x, _4138.y ? 0.0f.xx.y : _4130.y);
        bool2 _4144 = any(isnan(_4139)).xx;
        float2 _4145 = float2(_4144.x ? 0.0f.xx.x : _4139.x, _4144.y ? 0.0f.xx.y : _4139.y);
        bool2 _4150 = any(isinf(_4145)).xx;
        float2 _4151 = float2(_4150.x ? 0.0f.xx.x : _4145.x, _4150.y ? 0.0f.xx.y : _4145.y);
        float2 _4157 = float2(-_4151.x, _4151.y);
        float2 _2453 = float2(-_2854.x, _2854.y) * _3082;
        float2 _2457 = _2914 * _3082;
        float2 _4212 = _2453 * 16.0146636962890625f;
        float2 _4222 = float2(int2(clamp(sign(_4212) * ceil(abs(_4212)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4238 = _2457 * 16.0146636962890625f;
        float2 _4248 = float2(int2(clamp(sign(_4238) * ceil(abs(_4238)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5322;
        if (max(max(length(_4222), length(_4248)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5322 = 0.0f;
        }
        else
        {
            _5322 = float(length(_4222 - _4248) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2462 = uint(_5322 > 0.0f);
        float _2474 = length(_2457);
        if (_2474 > 4.0f)
        {
            if (_2924)
            {
                uint _4265;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4265);
            }
        }
        bool _2486 = ((cbFI_pad0 & 2048u) != 0u) && (_2462 != 0u);
        bool _2498;
        if (_2486)
        {
            _2498 = length(_2453 - _2457) < (0.07999999821186065673828125f * max(length(_2453), _2474));
        }
        else
        {
            _2498 = _2486;
        }
        uint _5423 = _2498 ? 0u : _2462;
        rw_dynamic_mask_tp1[_1933] = float4(clamp(float(_5423 + uint(_2821)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5423 != 0u)
        {
            if (_2924)
            {
                uint _4284;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4284);
            }
        }
        if (_2821 > 0.0f)
        {
            if (_2924)
            {
                uint _4294;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4294);
            }
        }
        if ((cbFI_NfruT2Flags & 512u) != 0u)
        {
            break;
        }
        bool _2526 = (cbFI_NfruT2Flags & 1024u) != 0u;
        bool _2532;
        if (_2526)
        {
            _2532 = (1.0f - (log(((_4084 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) < 0.300000011920928955078125f;
        }
        else
        {
            _2532 = _2526;
        }
        if (_2532)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1933, 0)).x) + uint(float(_4116 < 0.0f))) > 0u)
        {
            if (_2924)
            {
                uint _4314;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4314);
            }
            break;
        }
        float _4347 = 1.0f - (log(((_4084 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5337;
        if (_4347 == 1.0f)
        {
            _5337 = _4347 + ((float(_2218) * _2225) * 0.100000001490116119384765625f);
        }
        else
        {
            _5337 = _4347;
        }
        float _4337 = 1.10000002384185791015625f - _5337;
        float2 _5338;
        float2 _5339;
        do
        {
            if (_2941)
            {
                _5339 = _4157;
                _5338 = _4157;
                break;
            }
            float2 _4366 = _2231 + _4157;
            float _4402 = ((2.0f * _4366.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4369 = (float2(atan(_4402) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4366.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4402 * _4402))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5261;
            float2 _4451 = clamp((((_5261 + (_4369 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4454 = tan(_4451.x);
            _5339 = _4369;
            _5338 = (((float2(_4454 / cbFI_DeviceToViewDepth.z, (tan(_4451.y) * sqrt(1.0f + (_4454 * _4454))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2231) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5341;
        int2 _5342;
        uint _5350;
        do
        {
            float2 _4501 = _5338 * _3082;
            float2 _4505 = _5339 * _3082;
            bool _4508 = any(isnan(_4501));
            bool _4515;
            if (!_4508)
            {
                _4515 = any(isinf(_4501));
            }
            else
            {
                _4515 = _4508;
            }
            bool _4522;
            if (!_4515)
            {
                _4522 = any(isnan(_4505));
            }
            else
            {
                _4522 = _4515;
            }
            bool _4529;
            if (!_4522)
            {
                _4529 = any(isinf(_4505));
            }
            else
            {
                _4529 = _4522;
            }
            bool _4535;
            if (!_4529)
            {
                _4535 = isnan(_4337);
            }
            else
            {
                _4535 = _4529;
            }
            bool _4541;
            if (!_4535)
            {
                _4541 = isinf(_4337);
            }
            else
            {
                _4541 = _4535;
            }
            if (_4541)
            {
                _5350 = 0u;
                _5342 = int2(0, 0);
                _5341 = false;
                break;
            }
            float2 _4546 = _4501 * cbFI_Timestep;
            bool _4549 = any(isnan(_4546));
            bool _4556;
            if (!_4549)
            {
                _4556 = any(isinf(_4546));
            }
            else
            {
                _4556 = _4549;
            }
            if (_4556)
            {
                _5350 = 0u;
                _5342 = int2(0, 0);
                _5341 = false;
                break;
            }
            float2 _4563 = _2227 + floor(_4546);
            bool _4566 = any(bool2(_4563.x < 0.0f.xx.x, _4563.y < 0.0f.xx.y));
            bool _4575;
            if (!_4566)
            {
                _4575 = any(bool2(_4563.x >= _3082.x, _4563.y >= _3082.y));
            }
            else
            {
                _4575 = _4566;
            }
            if (_4575)
            {
                _5350 = 0u;
                _5342 = int2(0, 0);
                _5341 = false;
                break;
            }
            float2 _4582 = _4505 * (-1.0f);
            float _4629 = _4582.x * 16.0146636962890625f;
            int _4637 = int(clamp(sign(_4629) * ceil(abs(_4629)), -16383.0f, 16383.0f));
            float _4641 = _4582.y * 16.0146636962890625f;
            int _4649 = int(clamp(sign(_4641) * ceil(abs(_4641)), -16383.0f, 16383.0f));
            int _4656 = abs(_4637);
            int _4658 = abs(_4649);
            int _4662 = clamp(firstbithigh(max(_4656, _4658)), 0, 15);
            int _4665 = max((_4662 - 6), 0);
            _5350 = (((((uint((int(round(_4337 * 1860.9090576171875f)) & 2047) << 20) | uint((_4662 & 15) << 16)) | uint(int(_4637 < 0) << 15)) | uint(int(_4649 < 0) << 14)) | uint((clamp(_4656 >> _4665, 0, 127) & 127) << 7)) | uint(clamp(_4658 >> _4665, 0, 127) & 127)) & 2147483647u;
            _5342 = int2(_4563);
            _5341 = true;
            break;
        } while(false);
        if (_5341)
        {
            uint _4747;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5342], _5350, _4747);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5358 = 0; _5358 < 3; _5358++)
                {
                    int2 _2581 = _5342 + _1322[_5358];
                    if (all(bool2(_2581.x < cbFI_MvDepthLaneSize.x, _2581.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4752;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2581], _5350, _4752);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2603 = _2231 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2608 = _2231 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4769_dummy_parameter;
                float4 _4776 = r_depth_tm1.Load(int3(int2(floor(_2231 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4769_dummy_parameter))))), 0));
                float _4777 = _4776.x;
                uint _4785_dummy_parameter;
                float4 _4792 = r_depth_tm1.Load(int3(int2(floor(_2603 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4785_dummy_parameter))))), 0));
                float _4793 = _4792.x;
                uint _4801_dummy_parameter;
                float4 _4808 = r_depth_tm1.Load(int3(int2(floor(_2608 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4801_dummy_parameter))))), 0));
                float _4809 = _4808.x;
                float _4824 = _2603.x;
                float2 _4828 = float2(_4824, 1.0f - _2603.y);
                float4 _4839 = mul(float4((_4828 * 2.0f) - 1.0f.xx, _4793, 1.0f), cbFI_MotionTM1ToTP1);
                float _4841 = _4839.w;
                float2 _4855 = _4828 - (((_4839.xy / _4841.xx) + 1.0f.xx) * 0.5f);
                float2 _4857 = abs(_4855);
                bool2 _4863 = all(bool2(_4857.x < 9.9999997473787516355514526367188e-06f.xx.x, _4857.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4864 = float2(_4863.x ? 0.0f.xx.x : _4855.x, _4863.y ? 0.0f.xx.y : _4855.y);
                bool2 _4869 = any(isnan(_4864)).xx;
                float2 _4870 = float2(_4869.x ? 0.0f.xx.x : _4864.x, _4869.y ? 0.0f.xx.y : _4864.y);
                bool2 _4875 = any(isinf(_4870)).xx;
                float2 _4876 = float2(_4875.x ? 0.0f.xx.x : _4870.x, _4875.y ? 0.0f.xx.y : _4870.y);
                float _4898 = _2608.y;
                float2 _4900 = float2(_2608.x, 1.0f - _4898);
                float4 _4911 = mul(float4((_4900 * 2.0f) - 1.0f.xx, _4809, 1.0f), cbFI_MotionTM1ToTP1);
                float _4913 = _4911.w;
                float2 _4927 = _4900 - (((_4911.xy / _4913.xx) + 1.0f.xx) * 0.5f);
                float2 _4929 = abs(_4927);
                bool2 _4935 = all(bool2(_4929.x < 9.9999997473787516355514526367188e-06f.xx.x, _4929.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4936 = float2(_4935.x ? 0.0f.xx.x : _4927.x, _4935.y ? 0.0f.xx.y : _4927.y);
                bool2 _4941 = any(isnan(_4936)).xx;
                float2 _4942 = float2(_4941.x ? 0.0f.xx.x : _4936.x, _4941.y ? 0.0f.xx.y : _4936.y);
                bool2 _4947 = any(isinf(_4942)).xx;
                float2 _4948 = float2(_4947.x ? 0.0f.xx.x : _4942.x, _4947.y ? 0.0f.xx.y : _4942.y);
                bool _2630 = (_4824 < 1.0f) && (float(_4841 < 0.0f) == 0.0f);
                bool _2636;
                if (_2630)
                {
                    _2636 = abs(_4777 - _4793) <= ((0.0500000007450580596923828125f * max(abs(_4777), abs(_4793))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2636 = _2630;
                }
                bool _2642 = (_4898 < 1.0f) && (float(_4913 < 0.0f) == 0.0f);
                bool _2648;
                if (_2642)
                {
                    _2648 = abs(_4777 - _4809) <= ((0.0500000007450580596923828125f * max(abs(_4777), abs(_4809))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2648 = _2642;
                }
                float2 _4996 = (_2231 + (_4157 * cbFI_Timestep)) * _3082;
                float2 _5359;
                if (_2636)
                {
                    _5359 = ((_2603 + (float2(-_4876.x, _4876.y) * cbFI_Timestep)) * _3082) - _4996;
                }
                else
                {
                    _5359 = float2(1.0f, 0.0f);
                }
                float2 _5360;
                if (_2648)
                {
                    _5360 = ((_2608 + (float2(-_4948.x, _4948.y) * cbFI_Timestep)) * _3082) - _4996;
                }
                else
                {
                    _5360 = float2(0.0f, 1.0f);
                }
                bool _5050 = any(isnan(_5359));
                bool _5057;
                if (!_5050)
                {
                    _5057 = any(isinf(_5359));
                }
                else
                {
                    _5057 = _5050;
                }
                bool2 _5424 = _5057.xx;
                float2 _5425 = float2(_5424.x ? float2(1.0f, 0.0f).x : _5359.x, _5424.y ? float2(1.0f, 0.0f).y : _5359.y);
                bool _5062 = any(isnan(_5360));
                bool _5069;
                if (!_5062)
                {
                    _5069 = any(isinf(_5360));
                }
                else
                {
                    _5069 = _5062;
                }
                bool2 _5426 = _5069.xx;
                float2 _5427 = float2(_5426.x ? float2(0.0f, 1.0f).x : _5360.x, _5426.y ? float2(0.0f, 1.0f).y : _5360.y);
                int2 _5085 = int2(clamp(floor(min(0.0f.xx, _5425) + min(0.0f.xx, _5427)), (-3.0f).xx, 0.0f.xx));
                int2 _5091 = int2(clamp(ceil(max(0.0f.xx, _5425) + max(0.0f.xx, _5427)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5099 = _5085.y;
                for (int _5390 = _5099; _5390 <= _5091.y; _5390++)
                {
                    int _5108 = _5085.x;
                    for (int _5391 = _5108; _5391 <= _5091.x; _5391++)
                    {
                        if ((_5391 == 0) && (_5390 == 0))
                        {
                            continue;
                        }
                        int2 _5127 = _5342 + int2(_5391, _5390);
                        bool _5130 = all(bool2(_5127.x >= int2(0, 0).x, _5127.y >= int2(0, 0).y));
                        bool _5137;
                        if (_5130)
                        {
                            _5137 = all(bool2(_5127.x < cbFI_MvDepthLaneSize.x, _5127.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5137 = _5130;
                        }
                        if (_5137)
                        {
                            uint _5155;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5127], _5350, _5155);
                        }
                    }
                }
            }
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
