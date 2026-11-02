static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1305[3] = { int2(1, 0), int2(0, 1), int2(1, 1) };
static const int2 _1519[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

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
    int2 _1930 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1930.x >= cbFI_MvDepthLaneSize.x, _1930.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2213 = _1930.x + (_1930.y * cbFI_MvDepthLaneSize.x);
        float _2220 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2222 = float2(_1930);
        float2 _2226 = (_2222 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2709 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5262;
        if (_2709)
        {
            float _2722 = ((2.0f * _2226.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5262 = float2(atan(_2722) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2226.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2722 * _2722))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5262 = _2226;
        }
        uint _2764_dummy_parameter;
        float4 _2771 = r_depth_tp1.Load(int3(int2(floor(_2226 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2764_dummy_parameter))))), 0));
        float _2772 = _2771.x;
        uint _2780_dummy_parameter;
        float4 _2787 = r_depth_tp1.Load(int3(int2(floor(_2226 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2780_dummy_parameter))))), 0));
        float _2788 = _2787.x;
        float2 _2807 = float2(_2226.x, 1.0f - _2226.y);
        float2 _2811 = (_2807 * 2.0f) - 1.0f.xx;
        float _2813 = _2811.x;
        float4 _2818 = mul(float4(_2813, _2811.y, _2772, 1.0f), cbFI_MotionTP1ToTM1);
        float _2820 = _2818.w;
        float _2822 = float(_2820 < 0.0f);
        float2 _2834 = _2807 - (((_2818.xy / _2820.xx) + 1.0f.xx) * 0.5f);
        float2 _2836 = abs(_2834);
        bool2 _2842 = all(bool2(_2836.x < 9.9999997473787516355514526367188e-06f.xx.x, _2836.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2843 = float2(_2842.x ? 0.0f.xx.x : _2834.x, _2842.y ? 0.0f.xx.y : _2834.y);
        bool2 _2848 = any(isnan(_2843)).xx;
        float2 _2849 = float2(_2848.x ? 0.0f.xx.x : _2843.x, _2848.y ? 0.0f.xx.y : _2843.y);
        bool2 _2854 = any(isinf(_2849)).xx;
        float2 _2855 = float2(_2854.x ? 0.0f.xx.x : _2849.x, _2854.y ? 0.0f.xx.y : _2849.y);
        float _2893 = 1.0f - (log((_2772 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5263;
        if (_2893 == 1.0f)
        {
            _5263 = _2893 + ((float(_2213) * _2220) * 0.100000001490116119384765625f);
        }
        else
        {
            _5263 = _2893;
        }
        float _2883 = 1.10000002384185791015625f - _5263;
        uint _2900_dummy_parameter;
        float2 _2915 = r_motion_tp1.Load(int3(int2(floor(_2226 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2900_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _2925 = (cbFI_pad0 & 512u) != 0u;
        if (_2925)
        {
            uint _2929;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _2929);
        }
        bool _2942;
        float _2247 = 1.0f - cbFI_Timestep;
        float2 _5264;
        float2 _5265;
        do
        {
            _2942 = !_2709;
            if (_2942)
            {
                _5265 = _2915;
                _5264 = _2915;
                break;
            }
            float2 _2949 = _2226 + _2915;
            float _2985 = ((2.0f * _2949.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _2952 = (float2(atan(_2985) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2949.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2985 * _2985))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5262;
            float2 _3034 = clamp((((_5262 + (_2952 * _2247)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3037 = tan(_3034.x);
            _5265 = _2952;
            _5264 = (((float2(_3037 / cbFI_DeviceToViewDepth.z, (tan(_3034.y) * sqrt(1.0f + (_3037 * _3037))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2226) / max(_2247, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _3083;
        bool _5268;
        int2 _5269;
        uint _5277;
        do
        {
            _3083 = float2(cbFI_MvDepthLaneSize);
            float2 _3084 = _5264 * _3083;
            float2 _3088 = _5265 * _3083;
            bool _3091 = any(isnan(_3084));
            bool _3098;
            if (!_3091)
            {
                _3098 = any(isinf(_3084));
            }
            else
            {
                _3098 = _3091;
            }
            bool _3105;
            if (!_3098)
            {
                _3105 = any(isnan(_3088));
            }
            else
            {
                _3105 = _3098;
            }
            bool _3112;
            if (!_3105)
            {
                _3112 = any(isinf(_3088));
            }
            else
            {
                _3112 = _3105;
            }
            bool _3118;
            if (!_3112)
            {
                _3118 = isnan(_2883);
            }
            else
            {
                _3118 = _3112;
            }
            bool _3124;
            if (!_3118)
            {
                _3124 = isinf(_2883);
            }
            else
            {
                _3124 = _3118;
            }
            if (_3124)
            {
                _5277 = 0u;
                _5269 = int2(0, 0);
                _5268 = false;
                break;
            }
            float2 _3129 = _3084 * _2247;
            bool _3132 = any(isnan(_3129));
            bool _3139;
            if (!_3132)
            {
                _3139 = any(isinf(_3129));
            }
            else
            {
                _3139 = _3132;
            }
            if (_3139)
            {
                _5277 = 0u;
                _5269 = int2(0, 0);
                _5268 = false;
                break;
            }
            float2 _3146 = _2222 + floor(_3129);
            bool _3149 = any(bool2(_3146.x < 0.0f.xx.x, _3146.y < 0.0f.xx.y));
            bool _3158;
            if (!_3149)
            {
                _3158 = any(bool2(_3146.x >= _3083.x, _3146.y >= _3083.y));
            }
            else
            {
                _3158 = _3149;
            }
            if (_3158)
            {
                _5277 = 0u;
                _5269 = int2(0, 0);
                _5268 = false;
                break;
            }
            float2 _3165 = _3088 * 1.0f;
            float _3212 = _3165.x * 16.0146636962890625f;
            int _3220 = int(clamp(sign(_3212) * ceil(abs(_3212)), -16383.0f, 16383.0f));
            float _3224 = _3165.y * 16.0146636962890625f;
            int _3232 = int(clamp(sign(_3224) * ceil(abs(_3224)), -16383.0f, 16383.0f));
            int _3239 = abs(_3220);
            int _3241 = abs(_3232);
            int _3245 = clamp(firstbithigh(max(_3239, _3241)), 0, 15);
            int _3248 = max((_3245 - 6), 0);
            _5277 = (((((uint((int(round(_2883 * 1860.9090576171875f)) & 2047) << 20) | uint((_3245 & 15) << 16)) | uint(int(_3220 < 0) << 15)) | uint(int(_3232 < 0) << 14)) | uint((clamp(_3239 >> _3248, 0, 127) & 127) << 7)) | uint(clamp(_3241 >> _3248, 0, 127) & 127)) & 2147483647u;
            _5269 = int2(_3146);
            _5268 = true;
            break;
        } while(false);
        if (_5268)
        {
            if (_2925)
            {
                uint _3334;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3334);
            }
            uint _3340;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5269], _5277, _3340);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5287 = 0; _5287 < 3; _5287++)
                {
                    int2 _2282 = _5269 + _1305[_5287];
                    if (all(bool2(_2282.x < cbFI_MvDepthLaneSize.x, _2282.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3345;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2282], _5277, _3345);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2304 = _2226 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2309 = _2226 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2314 = _2304.x < 1.0f;
                bool _2321;
                if (_2314)
                {
                    uint _3366_dummy_parameter;
                    float4 _3373 = r_depth_tp1.Load(int3(int2(floor(_2304 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3366_dummy_parameter))))), 0));
                    float _3374 = _3373.x;
                    _2321 = abs(_2788 - _3374) <= ((0.0500000007450580596923828125f * max(abs(_2788), abs(_3374))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2321 = _2314;
                }
                bool _2324 = _2309.y < 1.0f;
                bool _2331;
                if (_2324)
                {
                    uint _3396_dummy_parameter;
                    float4 _3403 = r_depth_tp1.Load(int3(int2(floor(_2309 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3396_dummy_parameter))))), 0));
                    float _3404 = _3403.x;
                    _2331 = abs(_2788 - _3404) <= ((0.0500000007450580596923828125f * max(abs(_2788), abs(_3404))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2331 = _2324;
                }
                float2 _3429 = (_2226 + (_2915 * _2247)) * _3083;
                uint _3436_dummy_parameter;
                uint _3473_dummy_parameter;
                float2 _5288;
                if (_2321)
                {
                    _5288 = ((_2304 + ((r_motion_tp1.Load(int3(int2(floor(_2304 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3436_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2247)) * _3083) - _3429;
                }
                else
                {
                    _5288 = float2(1.0f, 0.0f);
                }
                float2 _5289;
                if (_2331)
                {
                    _5289 = ((_2309 + ((r_motion_tp1.Load(int3(int2(floor(_2309 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3473_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2247)) * _3083) - _3429;
                }
                else
                {
                    _5289 = float2(0.0f, 1.0f);
                }
                bool _3529 = any(isnan(_5288));
                bool _3536;
                if (!_3529)
                {
                    _3536 = any(isinf(_5288));
                }
                else
                {
                    _3536 = _3529;
                }
                bool2 _5422 = _3536.xx;
                float2 _5423 = float2(_5422.x ? float2(1.0f, 0.0f).x : _5288.x, _5422.y ? float2(1.0f, 0.0f).y : _5288.y);
                bool _3541 = any(isnan(_5289));
                bool _3548;
                if (!_3541)
                {
                    _3548 = any(isinf(_5289));
                }
                else
                {
                    _3548 = _3541;
                }
                bool2 _5424 = _3548.xx;
                float2 _5425 = float2(_5424.x ? float2(0.0f, 1.0f).x : _5289.x, _5424.y ? float2(0.0f, 1.0f).y : _5289.y);
                int2 _3564 = int2(clamp(floor(min(0.0f.xx, _5423) + min(0.0f.xx, _5425)), (-3.0f).xx, 0.0f.xx));
                int2 _3570 = int2(clamp(ceil(max(0.0f.xx, _5423) + max(0.0f.xx, _5425)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3578 = _3564.y;
                for (int _5319 = _3578; _5319 <= _3570.y; _5319++)
                {
                    int _3587 = _3564.x;
                    for (int _5404 = _3587; _5404 <= _3570.x; _5404++)
                    {
                        if ((_5404 == 0) && (_5319 == 0))
                        {
                            continue;
                        }
                        int2 _3606 = _5269 + int2(_5404, _5319);
                        bool _3609 = all(bool2(_3606.x >= int2(0, 0).x, _3606.y >= int2(0, 0).y));
                        bool _3616;
                        if (_3609)
                        {
                            _3616 = all(bool2(_3606.x < cbFI_MvDepthLaneSize.x, _3606.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3616 = _3609;
                        }
                        if (_3616)
                        {
                            uint _3634;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3606], _5277, _3634);
                        }
                    }
                }
            }
        }
        else
        {
            if (_2925)
            {
                uint _3643;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3643);
            }
        }
        uint _3652_dummy_parameter;
        int2 _3652 = int2(spvTextureSize(r_depth_tp1, uint(0), _3652_dummy_parameter));
        float _2054[9];
        _2054[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2226 * float2(_3652))), int2(0, 0), _3652 - int2(1, 1)), 0)).x;
        uint _3677_dummy_parameter;
        int2 _3677 = int2(spvTextureSize(r_depth_tp1, uint(0), _3677_dummy_parameter));
        _2054[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2226 * float2(_3677))) + int2(1, 0), int2(0, 0), _3677 - int2(1, 1)), 0)).x;
        uint _3702_dummy_parameter;
        int2 _3702 = int2(spvTextureSize(r_depth_tp1, uint(0), _3702_dummy_parameter));
        _2054[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2226 * float2(_3702))) + int2(0, 1), int2(0, 0), _3702 - int2(1, 1)), 0)).x;
        uint _3727_dummy_parameter;
        int2 _3727 = int2(spvTextureSize(r_depth_tp1, uint(0), _3727_dummy_parameter));
        _2054[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2226 * float2(_3727))) + int2(0, -1), int2(0, 0), _3727 - int2(1, 1)), 0)).x;
        uint _3752_dummy_parameter;
        int2 _3752 = int2(spvTextureSize(r_depth_tp1, uint(0), _3752_dummy_parameter));
        _2054[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2226 * float2(_3752))) + int2(-1, 0), int2(0, 0), _3752 - int2(1, 1)), 0)).x;
        uint _3777_dummy_parameter;
        int2 _3777 = int2(spvTextureSize(r_depth_tp1, uint(0), _3777_dummy_parameter));
        _2054[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2226 * float2(_3777))) + int2(-1, 1), int2(0, 0), _3777 - int2(1, 1)), 0)).x;
        uint _3802_dummy_parameter;
        int2 _3802 = int2(spvTextureSize(r_depth_tp1, uint(0), _3802_dummy_parameter));
        _2054[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2226 * float2(_3802))) + int2(1, 1), int2(0, 0), _3802 - int2(1, 1)), 0)).x;
        uint _3827_dummy_parameter;
        int2 _3827 = int2(spvTextureSize(r_depth_tp1, uint(0), _3827_dummy_parameter));
        _2054[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2226 * float2(_3827))) + int2(-1, -1), int2(0, 0), _3827 - int2(1, 1)), 0)).x;
        uint _3852_dummy_parameter;
        int2 _3852 = int2(spvTextureSize(r_depth_tp1, uint(0), _3852_dummy_parameter));
        _2054[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2226 * float2(_3852))) + int2(1, -1), int2(0, 0), _3852 - int2(1, 1)), 0)).x;
        int _5321;
        _5321 = 0;
        float _5426;
        int _5427;
        int _5320 = 1;
        float _5402 = _2054[0];
        for (; _5320 < 9; _5402 = _5426, _5321 = _5427, _5320++)
        {
            bool _2404 = _2054[_5320] > _5402;
            _5426 = _2404 ? _2054[_5320] : _5402;
            _5427 = _2404 ? _5320 : _5321;
        }
        uint _3877_dummy_parameter;
        int2 _3877 = int2(spvTextureSize(r_motion_tp1, uint(0), _3877_dummy_parameter));
        float2 _3895 = r_motion_tp1.Load(int3(clamp(int2(floor(_2226 * float2(_3877))) + _1519[_5321], int2(0, 0), _3877 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5322;
        do
        {
            if (_2942)
            {
                _5322 = _3895;
                break;
            }
            float2 _3919 = _2226 + _3895;
            float _3955 = ((2.0f * _3919.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4004 = clamp((((_5262 + (((float2(atan(_3955) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3919.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3955 * _3955))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5262) * _2247)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4007 = tan(_4004.x);
            _5322 = (((float2(_4007 / cbFI_DeviceToViewDepth.z, (tan(_4004.y) * sqrt(1.0f + (_4007 * _4007))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2226) / max(_2247, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        rw_mv_holes_tp1[_1930 + int2(floor((_5322 * _3083) * _2247))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1930 + int2(floor(_3895 * _3083))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4077_dummy_parameter;
        float4 _4084 = r_depth_tm1.Load(int3(int2(floor(_2226 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4077_dummy_parameter))))), 0));
        float _4085 = _4084.x;
        float4 _4115 = mul(float4(_2813, _2811.y, _4085, 1.0f), cbFI_MotionTM1ToTP1);
        float _4117 = _4115.w;
        float2 _4131 = _2807 - (((_4115.xy / _4117.xx) + 1.0f.xx) * 0.5f);
        float2 _4133 = abs(_4131);
        bool2 _4139 = all(bool2(_4133.x < 9.9999997473787516355514526367188e-06f.xx.x, _4133.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4140 = float2(_4139.x ? 0.0f.xx.x : _4131.x, _4139.y ? 0.0f.xx.y : _4131.y);
        bool2 _4145 = any(isnan(_4140)).xx;
        float2 _4146 = float2(_4145.x ? 0.0f.xx.x : _4140.x, _4145.y ? 0.0f.xx.y : _4140.y);
        bool2 _4151 = any(isinf(_4146)).xx;
        float2 _4152 = float2(_4151.x ? 0.0f.xx.x : _4146.x, _4151.y ? 0.0f.xx.y : _4146.y);
        float2 _4158 = float2(-_4152.x, _4152.y);
        float2 _2445 = float2(-_2855.x, _2855.y) * _3083;
        float2 _2449 = _2915 * _3083;
        float2 _4213 = _2445 * 16.0146636962890625f;
        float2 _4223 = float2(int2(clamp(sign(_4213) * ceil(abs(_4213)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4239 = _2449 * 16.0146636962890625f;
        float2 _4249 = float2(int2(clamp(sign(_4239) * ceil(abs(_4239)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5323;
        if (max(max(length(_4223), length(_4249)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5323 = 0.0f;
        }
        else
        {
            _5323 = float(length(_4223 - _4249) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2454 = uint(_5323 > 0.0f);
        float _2466 = length(_2449);
        if (_2466 > 4.0f)
        {
            if (_2925)
            {
                uint _4266;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4266);
            }
        }
        bool _2478 = ((cbFI_pad0 & 2048u) != 0u) && (_2454 != 0u);
        bool _2490;
        if (_2478)
        {
            _2490 = length(_2445 - _2449) < (0.07999999821186065673828125f * max(length(_2445), _2466));
        }
        else
        {
            _2490 = _2478;
        }
        bool _2496 = (cbFI_NfruT2Flags & 2048u) != 0u;
        bool _2504;
        if (_2496)
        {
            _2504 = length(_2445 - _2449) > 2.0f;
        }
        else
        {
            _2504 = _2496;
        }
        uint _5429 = _2504 ? 1u : (_2490 ? 0u : _2454);
        rw_dynamic_mask_tp1[_1930] = float4(clamp(float(_5429 + uint(_2822)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5429 != 0u)
        {
            if (_2925)
            {
                uint _4285;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4285);
            }
        }
        if (_2822 > 0.0f)
        {
            if (_2925)
            {
                uint _4295;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4295);
            }
        }
        if ((cbFI_NfruT2Flags & 512u) != 0u)
        {
            break;
        }
        bool _2532 = (cbFI_NfruT2Flags & 1024u) != 0u;
        bool _2538;
        if (_2532)
        {
            _2538 = (1.0f - (log((_4085 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) < 0.300000011920928955078125f;
        }
        else
        {
            _2538 = _2532;
        }
        if (_2538)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1930, 0)).x) + uint(float(_4117 < 0.0f))) > 0u)
        {
            if (_2925)
            {
                uint _4315;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4315);
            }
            break;
        }
        float _4348 = 1.0f - (log((_4085 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5342;
        if (_4348 == 1.0f)
        {
            _5342 = _4348 + ((float(_2213) * _2220) * 0.100000001490116119384765625f);
        }
        else
        {
            _5342 = _4348;
        }
        float _4338 = 1.10000002384185791015625f - _5342;
        float2 _5343;
        float2 _5344;
        do
        {
            if (_2942)
            {
                _5344 = _4158;
                _5343 = _4158;
                break;
            }
            float2 _4367 = _2226 + _4158;
            float _4403 = ((2.0f * _4367.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4370 = (float2(atan(_4403) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4367.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4403 * _4403))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5262;
            float2 _4452 = clamp((((_5262 + (_4370 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4455 = tan(_4452.x);
            _5344 = _4370;
            _5343 = (((float2(_4455 / cbFI_DeviceToViewDepth.z, (tan(_4452.y) * sqrt(1.0f + (_4455 * _4455))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2226) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5346;
        int2 _5347;
        uint _5355;
        do
        {
            float2 _4502 = _5343 * _3083;
            float2 _4506 = _5344 * _3083;
            bool _4509 = any(isnan(_4502));
            bool _4516;
            if (!_4509)
            {
                _4516 = any(isinf(_4502));
            }
            else
            {
                _4516 = _4509;
            }
            bool _4523;
            if (!_4516)
            {
                _4523 = any(isnan(_4506));
            }
            else
            {
                _4523 = _4516;
            }
            bool _4530;
            if (!_4523)
            {
                _4530 = any(isinf(_4506));
            }
            else
            {
                _4530 = _4523;
            }
            bool _4536;
            if (!_4530)
            {
                _4536 = isnan(_4338);
            }
            else
            {
                _4536 = _4530;
            }
            bool _4542;
            if (!_4536)
            {
                _4542 = isinf(_4338);
            }
            else
            {
                _4542 = _4536;
            }
            if (_4542)
            {
                _5355 = 0u;
                _5347 = int2(0, 0);
                _5346 = false;
                break;
            }
            float2 _4547 = _4502 * cbFI_Timestep;
            bool _4550 = any(isnan(_4547));
            bool _4557;
            if (!_4550)
            {
                _4557 = any(isinf(_4547));
            }
            else
            {
                _4557 = _4550;
            }
            if (_4557)
            {
                _5355 = 0u;
                _5347 = int2(0, 0);
                _5346 = false;
                break;
            }
            float2 _4564 = _2222 + floor(_4547);
            bool _4567 = any(bool2(_4564.x < 0.0f.xx.x, _4564.y < 0.0f.xx.y));
            bool _4576;
            if (!_4567)
            {
                _4576 = any(bool2(_4564.x >= _3083.x, _4564.y >= _3083.y));
            }
            else
            {
                _4576 = _4567;
            }
            if (_4576)
            {
                _5355 = 0u;
                _5347 = int2(0, 0);
                _5346 = false;
                break;
            }
            float2 _4583 = _4506 * (-1.0f);
            float _4630 = _4583.x * 16.0146636962890625f;
            int _4638 = int(clamp(sign(_4630) * ceil(abs(_4630)), -16383.0f, 16383.0f));
            float _4642 = _4583.y * 16.0146636962890625f;
            int _4650 = int(clamp(sign(_4642) * ceil(abs(_4642)), -16383.0f, 16383.0f));
            int _4657 = abs(_4638);
            int _4659 = abs(_4650);
            int _4663 = clamp(firstbithigh(max(_4657, _4659)), 0, 15);
            int _4666 = max((_4663 - 6), 0);
            _5355 = (((((uint((int(round(_4338 * 1860.9090576171875f)) & 2047) << 20) | uint((_4663 & 15) << 16)) | uint(int(_4638 < 0) << 15)) | uint(int(_4650 < 0) << 14)) | uint((clamp(_4657 >> _4666, 0, 127) & 127) << 7)) | uint(clamp(_4659 >> _4666, 0, 127) & 127)) & 2147483647u;
            _5347 = int2(_4564);
            _5346 = true;
            break;
        } while(false);
        if (_5346)
        {
            uint _4748;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5347], _5355, _4748);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5363 = 0; _5363 < 3; _5363++)
                {
                    int2 _2587 = _5347 + _1305[_5363];
                    if (all(bool2(_2587.x < cbFI_MvDepthLaneSize.x, _2587.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4753;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2587], _5355, _4753);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2609 = _2226 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2614 = _2226 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4770_dummy_parameter;
                float4 _4777 = r_depth_tm1.Load(int3(int2(floor(_2226 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4770_dummy_parameter))))), 0));
                float _4778 = _4777.x;
                uint _4786_dummy_parameter;
                float4 _4793 = r_depth_tm1.Load(int3(int2(floor(_2609 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4786_dummy_parameter))))), 0));
                float _4794 = _4793.x;
                uint _4802_dummy_parameter;
                float4 _4809 = r_depth_tm1.Load(int3(int2(floor(_2614 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4802_dummy_parameter))))), 0));
                float _4810 = _4809.x;
                float _4825 = _2609.x;
                float2 _4829 = float2(_4825, 1.0f - _2609.y);
                float4 _4840 = mul(float4((_4829 * 2.0f) - 1.0f.xx, _4794, 1.0f), cbFI_MotionTM1ToTP1);
                float _4842 = _4840.w;
                float2 _4856 = _4829 - (((_4840.xy / _4842.xx) + 1.0f.xx) * 0.5f);
                float2 _4858 = abs(_4856);
                bool2 _4864 = all(bool2(_4858.x < 9.9999997473787516355514526367188e-06f.xx.x, _4858.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4865 = float2(_4864.x ? 0.0f.xx.x : _4856.x, _4864.y ? 0.0f.xx.y : _4856.y);
                bool2 _4870 = any(isnan(_4865)).xx;
                float2 _4871 = float2(_4870.x ? 0.0f.xx.x : _4865.x, _4870.y ? 0.0f.xx.y : _4865.y);
                bool2 _4876 = any(isinf(_4871)).xx;
                float2 _4877 = float2(_4876.x ? 0.0f.xx.x : _4871.x, _4876.y ? 0.0f.xx.y : _4871.y);
                float _4899 = _2614.y;
                float2 _4901 = float2(_2614.x, 1.0f - _4899);
                float4 _4912 = mul(float4((_4901 * 2.0f) - 1.0f.xx, _4810, 1.0f), cbFI_MotionTM1ToTP1);
                float _4914 = _4912.w;
                float2 _4928 = _4901 - (((_4912.xy / _4914.xx) + 1.0f.xx) * 0.5f);
                float2 _4930 = abs(_4928);
                bool2 _4936 = all(bool2(_4930.x < 9.9999997473787516355514526367188e-06f.xx.x, _4930.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4937 = float2(_4936.x ? 0.0f.xx.x : _4928.x, _4936.y ? 0.0f.xx.y : _4928.y);
                bool2 _4942 = any(isnan(_4937)).xx;
                float2 _4943 = float2(_4942.x ? 0.0f.xx.x : _4937.x, _4942.y ? 0.0f.xx.y : _4937.y);
                bool2 _4948 = any(isinf(_4943)).xx;
                float2 _4949 = float2(_4948.x ? 0.0f.xx.x : _4943.x, _4948.y ? 0.0f.xx.y : _4943.y);
                bool _2636 = (_4825 < 1.0f) && (float(_4842 < 0.0f) == 0.0f);
                bool _2642;
                if (_2636)
                {
                    _2642 = abs(_4778 - _4794) <= ((0.0500000007450580596923828125f * max(abs(_4778), abs(_4794))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2642 = _2636;
                }
                bool _2648 = (_4899 < 1.0f) && (float(_4914 < 0.0f) == 0.0f);
                bool _2654;
                if (_2648)
                {
                    _2654 = abs(_4778 - _4810) <= ((0.0500000007450580596923828125f * max(abs(_4778), abs(_4810))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2654 = _2648;
                }
                float2 _4997 = (_2226 + (_4158 * cbFI_Timestep)) * _3083;
                float2 _5364;
                if (_2642)
                {
                    _5364 = ((_2609 + (float2(-_4877.x, _4877.y) * cbFI_Timestep)) * _3083) - _4997;
                }
                else
                {
                    _5364 = float2(1.0f, 0.0f);
                }
                float2 _5365;
                if (_2654)
                {
                    _5365 = ((_2614 + (float2(-_4949.x, _4949.y) * cbFI_Timestep)) * _3083) - _4997;
                }
                else
                {
                    _5365 = float2(0.0f, 1.0f);
                }
                bool _5051 = any(isnan(_5364));
                bool _5058;
                if (!_5051)
                {
                    _5058 = any(isinf(_5364));
                }
                else
                {
                    _5058 = _5051;
                }
                bool2 _5430 = _5058.xx;
                float2 _5431 = float2(_5430.x ? float2(1.0f, 0.0f).x : _5364.x, _5430.y ? float2(1.0f, 0.0f).y : _5364.y);
                bool _5063 = any(isnan(_5365));
                bool _5070;
                if (!_5063)
                {
                    _5070 = any(isinf(_5365));
                }
                else
                {
                    _5070 = _5063;
                }
                bool2 _5432 = _5070.xx;
                float2 _5433 = float2(_5432.x ? float2(0.0f, 1.0f).x : _5365.x, _5432.y ? float2(0.0f, 1.0f).y : _5365.y);
                int2 _5086 = int2(clamp(floor(min(0.0f.xx, _5431) + min(0.0f.xx, _5433)), (-3.0f).xx, 0.0f.xx));
                int2 _5092 = int2(clamp(ceil(max(0.0f.xx, _5431) + max(0.0f.xx, _5433)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5100 = _5086.y;
                for (int _5395 = _5100; _5395 <= _5092.y; _5395++)
                {
                    int _5109 = _5086.x;
                    for (int _5396 = _5109; _5396 <= _5092.x; _5396++)
                    {
                        if ((_5396 == 0) && (_5395 == 0))
                        {
                            continue;
                        }
                        int2 _5128 = _5347 + int2(_5396, _5395);
                        bool _5131 = all(bool2(_5128.x >= int2(0, 0).x, _5128.y >= int2(0, 0).y));
                        bool _5138;
                        if (_5131)
                        {
                            _5138 = all(bool2(_5128.x < cbFI_MvDepthLaneSize.x, _5128.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5138 = _5131;
                        }
                        if (_5138)
                        {
                            uint _5156;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5128], _5355, _5156);
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
