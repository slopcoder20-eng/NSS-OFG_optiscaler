static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static int2 _5929;
static uint _5942;

static const int2 _1457[3] = { int2(1, 0), int2(0, 1), int2(1, 1) };
static const int2 _1670[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

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
    int2 _2085 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_2085.x >= cbFI_MvDepthLaneSize.x, _2085.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2385 = _2085.x + (_2085.y * cbFI_MvDepthLaneSize.x);
        int _2390 = cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y;
        float _2392 = 1.0f / float(_2390);
        float2 _2394 = float2(_2085);
        float2 _2398 = (_2394 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2920 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5881;
        if (_2920)
        {
            float _2933 = ((2.0f * _2398.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5881 = float2(atan(_2933) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2398.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2933 * _2933))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5881 = _2398;
        }
        uint _3027;
        bool _3029;
        uint _2975_dummy_parameter;
        float4 _2982 = r_depth_tp1.Load(int3(int2(floor(_2398 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2975_dummy_parameter))))), 0));
        float _2983 = _2982.x;
        uint _2991_dummy_parameter;
        float4 _2998 = r_depth_tp1.Load(int3(int2(floor(_2398 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2991_dummy_parameter))))), 0));
        float _2999 = _2998.x;
        float4x4 _5886;
        do
        {
            float4x4 _3005;
            bool _5885;
            do
            {
                _3005 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                _3027 = cbFI_NfruT2Flags;
                _3029 = (_3027 & 524288u) == 0u;
                if (_3029)
                {
                    _5885 = false;
                    break;
                }
                uint _3039 = (64u + uint(_2390)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                if (rw_nfru_diagnostics.Load<uint>((_3039 + 32u) * 4 + 0) != 1u)
                {
                    _5885 = false;
                    break;
                }
                uint _5882;
                _5882 = 0u;
                for (; _5882 < 4u; _5882++)
                {
                    for (uint _5883 = 0u; _5883 < 4u; )
                    {
                        _3005[_5882][_5883] = asfloat(rw_nfru_diagnostics.Load<uint>(((_3039 + (_5882 * 4u)) + _5883) * 4 + 0));
                        _5883++;
                        continue;
                    }
                }
                _5885 = true;
                break;
            } while(false);
            if (_5885)
            {
                _5886 = _3005;
                break;
            }
            _5886 = cbFI_MotionTP1ToTM1;
            break;
        } while(false);
        float2 _3120 = float2(_2398.x, 1.0f - _2398.y);
        float2 _3124 = (_3120 * 2.0f) - 1.0f.xx;
        float _3126 = _3124.x;
        float4 _3131 = mul(float4(_3126, _3124.y, _2983, 1.0f), _5886);
        float _3133 = _3131.w;
        float _3135 = float(_3133 < 0.0f);
        float2 _3147 = _3120 - (((_3131.xy / _3133.xx) + 1.0f.xx) * 0.5f);
        float2 _3149 = abs(_3147);
        bool2 _3155 = all(bool2(_3149.x < 9.9999997473787516355514526367188e-06f.xx.x, _3149.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _3156 = float2(_3155.x ? 0.0f.xx.x : _3147.x, _3155.y ? 0.0f.xx.y : _3147.y);
        bool2 _3161 = any(isnan(_3156)).xx;
        float2 _3162 = float2(_3161.x ? 0.0f.xx.x : _3156.x, _3161.y ? 0.0f.xx.y : _3156.y);
        bool2 _3167 = any(isinf(_3162)).xx;
        float2 _3168 = float2(_3167.x ? 0.0f.xx.x : _3162.x, _3167.y ? 0.0f.xx.y : _3162.y);
        float2 _3174 = float2(-_3168.x, _3168.y);
        float _3206 = 1.0f - (log((_2983 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5891;
        if (_3206 == 1.0f)
        {
            _5891 = _3206 + ((float(_2385) * _2392) * 0.100000001490116119384765625f);
        }
        else
        {
            _5891 = _3206;
        }
        float _3196 = 1.10000002384185791015625f - _5891;
        uint _3213_dummy_parameter;
        float2 _3228 = r_motion_tp1.Load(int3(int2(floor(_2398 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3213_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _3238 = (cbFI_pad0 & 512u) != 0u;
        if (_3238)
        {
            uint _3242;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _3242);
        }
        bool _3255;
        float _2419 = 1.0f - cbFI_Timestep;
        float2 _5892;
        float2 _5893;
        do
        {
            _3255 = !_2920;
            if (_3255)
            {
                _5893 = _3228;
                _5892 = _3228;
                break;
            }
            float2 _3262 = _2398 + _3228;
            float _3298 = ((2.0f * _3262.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _3265 = (float2(atan(_3298) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3262.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3298 * _3298))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5881;
            float2 _3347 = clamp((((_5881 + (_3265 * _2419)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3350 = tan(_3347.x);
            _5893 = _3265;
            _5892 = (((float2(_3350 / cbFI_DeviceToViewDepth.z, (tan(_3347.y) * sqrt(1.0f + (_3350 * _3350))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2398) / max(_2419, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5894;
        if ((_3027 & 262144u) != 0u)
        {
            float2 _2432 = float2(cbFI_MvDepthLaneSize);
            float _2434 = length(_3174 * _2432);
            bool _2444 = (_3135 == 0.0f) && (_2434 > 8.0f);
            bool _2451;
            if (_2444)
            {
                _2451 = length(_3228 * _2432) < (0.20000000298023223876953125f * _2434);
            }
            else
            {
                _2451 = _2444;
            }
            _5894 = _2451;
        }
        else
        {
            _5894 = false;
        }
        bool _2454 = !_5894;
        bool _2467;
        int2 _5921;
        uint _5934;
        if (_2454)
        {
            bool _5903;
            int2 _5904;
            uint _5912;
            do
            {
                float2 _3396 = float2(cbFI_MvDepthLaneSize);
                float2 _3397 = _5892 * _3396;
                float2 _3401 = _5893 * _3396;
                bool _3404 = any(isnan(_3397));
                bool _3411;
                if (!_3404)
                {
                    _3411 = any(isinf(_3397));
                }
                else
                {
                    _3411 = _3404;
                }
                bool _3418;
                if (!_3411)
                {
                    _3418 = any(isnan(_3401));
                }
                else
                {
                    _3418 = _3411;
                }
                bool _3425;
                if (!_3418)
                {
                    _3425 = any(isinf(_3401));
                }
                else
                {
                    _3425 = _3418;
                }
                bool _3431;
                if (!_3425)
                {
                    _3431 = isnan(_3196);
                }
                else
                {
                    _3431 = _3425;
                }
                bool _3437;
                if (!_3431)
                {
                    _3437 = isinf(_3196);
                }
                else
                {
                    _3437 = _3431;
                }
                if (_3437)
                {
                    _5912 = 0u;
                    _5904 = int2(0, 0);
                    _5903 = false;
                    break;
                }
                float2 _3442 = _3397 * _2419;
                bool _3445 = any(isnan(_3442));
                bool _3452;
                if (!_3445)
                {
                    _3452 = any(isinf(_3442));
                }
                else
                {
                    _3452 = _3445;
                }
                if (_3452)
                {
                    _5912 = 0u;
                    _5904 = int2(0, 0);
                    _5903 = false;
                    break;
                }
                float2 _3459 = _2394 + floor(_3442);
                bool _3462 = any(bool2(_3459.x < 0.0f.xx.x, _3459.y < 0.0f.xx.y));
                bool _3471;
                if (!_3462)
                {
                    _3471 = any(bool2(_3459.x >= _3396.x, _3459.y >= _3396.y));
                }
                else
                {
                    _3471 = _3462;
                }
                if (_3471)
                {
                    _5912 = 0u;
                    _5904 = int2(0, 0);
                    _5903 = false;
                    break;
                }
                float2 _3478 = _3401 * 1.0f;
                float _3525 = _3478.x * 16.0146636962890625f;
                int _3533 = int(clamp(sign(_3525) * ceil(abs(_3525)), -16383.0f, 16383.0f));
                float _3537 = _3478.y * 16.0146636962890625f;
                int _3545 = int(clamp(sign(_3537) * ceil(abs(_3537)), -16383.0f, 16383.0f));
                int _3552 = abs(_3533);
                int _3554 = abs(_3545);
                int _3558 = clamp(firstbithigh(max(_3552, _3554)), 0, 15);
                int _3561 = max((_3558 - 6), 0);
                _5912 = (((((uint((int(round(_3196 * 1860.9090576171875f)) & 2047) << 20) | uint((_3558 & 15) << 16)) | uint(int(_3533 < 0) << 15)) | uint(int(_3545 < 0) << 14)) | uint((clamp(_3552 >> _3561, 0, 127) & 127) << 7)) | uint(clamp(_3554 >> _3561, 0, 127) & 127)) & 2147483647u;
                _5904 = int2(_3459);
                _5903 = true;
                break;
            } while(false);
            _5934 = _5912;
            _5921 = _5904;
            _2467 = _5903;
        }
        else
        {
            _5934 = _5942;
            _5921 = _5929;
            _2467 = _2454;
        }
        if (_2467)
        {
            if (_3238)
            {
                uint _3647;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3647);
            }
            uint _3653;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5921], _5934, _3653);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5946 = 0; _5946 < 3; _5946++)
                {
                    int2 _2487 = _5921 + _1457[_5946];
                    if (all(bool2(_2487.x < cbFI_MvDepthLaneSize.x, _2487.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3658;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2487], _5934, _3658);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2509 = _2398 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2514 = _2398 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2519 = _2509.x < 1.0f;
                bool _2526;
                if (_2519)
                {
                    uint _3679_dummy_parameter;
                    float4 _3686 = r_depth_tp1.Load(int3(int2(floor(_2509 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3679_dummy_parameter))))), 0));
                    float _3687 = _3686.x;
                    _2526 = abs(_2999 - _3687) <= ((0.0500000007450580596923828125f * max(abs(_2999), abs(_3687))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2526 = _2519;
                }
                bool _2529 = _2514.y < 1.0f;
                bool _2536;
                if (_2529)
                {
                    uint _3709_dummy_parameter;
                    float4 _3716 = r_depth_tp1.Load(int3(int2(floor(_2514 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3709_dummy_parameter))))), 0));
                    float _3717 = _3716.x;
                    _2536 = abs(_2999 - _3717) <= ((0.0500000007450580596923828125f * max(abs(_2999), abs(_3717))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2536 = _2529;
                }
                float2 _3741 = float2(cbFI_MvDepthLaneSize);
                float2 _3742 = (_2398 + (_3228 * _2419)) * _3741;
                uint _3749_dummy_parameter;
                uint _3786_dummy_parameter;
                float2 _5947;
                if (_2526)
                {
                    _5947 = ((_2509 + ((r_motion_tp1.Load(int3(int2(floor(_2509 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3749_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2419)) * _3741) - _3742;
                }
                else
                {
                    _5947 = float2(1.0f, 0.0f);
                }
                float2 _5948;
                if (_2536)
                {
                    _5948 = ((_2514 + ((r_motion_tp1.Load(int3(int2(floor(_2514 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3786_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2419)) * _3741) - _3742;
                }
                else
                {
                    _5948 = float2(0.0f, 1.0f);
                }
                bool _3842 = any(isnan(_5947));
                bool _3849;
                if (!_3842)
                {
                    _3849 = any(isinf(_5947));
                }
                else
                {
                    _3849 = _3842;
                }
                bool2 _6118 = _3849.xx;
                float2 _6119 = float2(_6118.x ? float2(1.0f, 0.0f).x : _5947.x, _6118.y ? float2(1.0f, 0.0f).y : _5947.y);
                bool _3854 = any(isnan(_5948));
                bool _3861;
                if (!_3854)
                {
                    _3861 = any(isinf(_5948));
                }
                else
                {
                    _3861 = _3854;
                }
                bool2 _6120 = _3861.xx;
                float2 _6121 = float2(_6120.x ? float2(0.0f, 1.0f).x : _5948.x, _6120.y ? float2(0.0f, 1.0f).y : _5948.y);
                int2 _3877 = int2(clamp(floor(min(0.0f.xx, _6119) + min(0.0f.xx, _6121)), (-3.0f).xx, 0.0f.xx));
                int2 _3883 = int2(clamp(ceil(max(0.0f.xx, _6119) + max(0.0f.xx, _6121)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3891 = _3877.y;
                for (int _5978 = _3891; _5978 <= _3883.y; _5978++)
                {
                    int _3900 = _3877.x;
                    for (int _6100 = _3900; _6100 <= _3883.x; _6100++)
                    {
                        if ((_6100 == 0) && (_5978 == 0))
                        {
                            continue;
                        }
                        int2 _3919 = _5921 + int2(_6100, _5978);
                        bool _3922 = all(bool2(_3919.x >= int2(0, 0).x, _3919.y >= int2(0, 0).y));
                        bool _3929;
                        if (_3922)
                        {
                            _3929 = all(bool2(_3919.x < cbFI_MvDepthLaneSize.x, _3919.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3929 = _3922;
                        }
                        if (_3929)
                        {
                            uint _3947;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3919], _5934, _3947);
                        }
                    }
                }
            }
        }
        else
        {
            if (_3238)
            {
                uint _3956;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3956);
            }
        }
        uint _3965_dummy_parameter;
        int2 _3965 = int2(spvTextureSize(r_depth_tp1, uint(0), _3965_dummy_parameter));
        float _2226[9];
        _2226[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2398 * float2(_3965))), int2(0, 0), _3965 - int2(1, 1)), 0)).x;
        uint _3990_dummy_parameter;
        int2 _3990 = int2(spvTextureSize(r_depth_tp1, uint(0), _3990_dummy_parameter));
        _2226[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2398 * float2(_3990))) + int2(1, 0), int2(0, 0), _3990 - int2(1, 1)), 0)).x;
        uint _4015_dummy_parameter;
        int2 _4015 = int2(spvTextureSize(r_depth_tp1, uint(0), _4015_dummy_parameter));
        _2226[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2398 * float2(_4015))) + int2(0, 1), int2(0, 0), _4015 - int2(1, 1)), 0)).x;
        uint _4040_dummy_parameter;
        int2 _4040 = int2(spvTextureSize(r_depth_tp1, uint(0), _4040_dummy_parameter));
        _2226[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2398 * float2(_4040))) + int2(0, -1), int2(0, 0), _4040 - int2(1, 1)), 0)).x;
        uint _4065_dummy_parameter;
        int2 _4065 = int2(spvTextureSize(r_depth_tp1, uint(0), _4065_dummy_parameter));
        _2226[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2398 * float2(_4065))) + int2(-1, 0), int2(0, 0), _4065 - int2(1, 1)), 0)).x;
        uint _4090_dummy_parameter;
        int2 _4090 = int2(spvTextureSize(r_depth_tp1, uint(0), _4090_dummy_parameter));
        _2226[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2398 * float2(_4090))) + int2(-1, 1), int2(0, 0), _4090 - int2(1, 1)), 0)).x;
        uint _4115_dummy_parameter;
        int2 _4115 = int2(spvTextureSize(r_depth_tp1, uint(0), _4115_dummy_parameter));
        _2226[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2398 * float2(_4115))) + int2(1, 1), int2(0, 0), _4115 - int2(1, 1)), 0)).x;
        uint _4140_dummy_parameter;
        int2 _4140 = int2(spvTextureSize(r_depth_tp1, uint(0), _4140_dummy_parameter));
        _2226[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2398 * float2(_4140))) + int2(-1, -1), int2(0, 0), _4140 - int2(1, 1)), 0)).x;
        uint _4165_dummy_parameter;
        int2 _4165 = int2(spvTextureSize(r_depth_tp1, uint(0), _4165_dummy_parameter));
        _2226[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2398 * float2(_4165))) + int2(1, -1), int2(0, 0), _4165 - int2(1, 1)), 0)).x;
        int _5980;
        _5980 = 0;
        float _6122;
        int _6123;
        int _5979 = 1;
        float _6098 = _2226[0];
        for (; _5979 < 9; _6098 = _6122, _5980 = _6123, _5979++)
        {
            bool _2609 = _2226[_5979] > _6098;
            _6122 = _2609 ? _2226[_5979] : _6098;
            _6123 = _2609 ? _5979 : _5980;
        }
        uint _4190_dummy_parameter;
        int2 _4190 = int2(spvTextureSize(r_motion_tp1, uint(0), _4190_dummy_parameter));
        float2 _4208 = r_motion_tp1.Load(int3(clamp(int2(floor(_2398 * float2(_4190))) + _1670[_5980], int2(0, 0), _4190 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5981;
        do
        {
            if (_3255)
            {
                _5981 = _4208;
                break;
            }
            float2 _4232 = _2398 + _4208;
            float _4268 = ((2.0f * _4232.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4317 = clamp((((_5881 + (((float2(atan(_4268) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4232.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4268 * _4268))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5881) * _2419)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4320 = tan(_4317.x);
            _5981 = (((float2(_4320 / cbFI_DeviceToViewDepth.z, (tan(_4317.y) * sqrt(1.0f + (_4320 * _4320))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2398) / max(_2419, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _4354 = float2(cbFI_MvDepthLaneSize);
        rw_mv_holes_tp1[_2085 + int2(floor((_5981 * _4354) * _2419))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_2085 + int2(floor(_4208 * _4354))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4390_dummy_parameter;
        float4 _4397 = r_depth_tm1.Load(int3(int2(floor(_2398 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4390_dummy_parameter))))), 0));
        float _4398 = _4397.x;
        float4x4 _5986;
        do
        {
            float4x4 _4404;
            bool _5985;
            do
            {
                _4404 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                if (_3029)
                {
                    _5985 = false;
                    break;
                }
                uint _4438 = (64u + uint(_2390)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                if (rw_nfru_diagnostics.Load<uint>((_4438 + 32u) * 4 + 0) != 1u)
                {
                    _5985 = false;
                    break;
                }
                uint _5982;
                _5982 = 0u;
                for (; _5982 < 4u; _5982++)
                {
                    for (uint _5983 = 0u; _5983 < 4u; )
                    {
                        _4404[_5982][_5983] = asfloat(rw_nfru_diagnostics.Load<uint>((((_4438 + 16u) + (_5982 * 4u)) + _5983) * 4 + 0));
                        _5983++;
                        continue;
                    }
                }
                _5985 = true;
                break;
            } while(false);
            if (_5985)
            {
                _5986 = _4404;
                break;
            }
            _5986 = cbFI_MotionTM1ToTP1;
            break;
        } while(false);
        float4 _4530 = mul(float4(_3126, _3124.y, _4398, 1.0f), _5986);
        float _4532 = _4530.w;
        float2 _4546 = _3120 - (((_4530.xy / _4532.xx) + 1.0f.xx) * 0.5f);
        float2 _4548 = abs(_4546);
        bool2 _4554 = all(bool2(_4548.x < 9.9999997473787516355514526367188e-06f.xx.x, _4548.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4555 = float2(_4554.x ? 0.0f.xx.x : _4546.x, _4554.y ? 0.0f.xx.y : _4546.y);
        bool2 _4560 = any(isnan(_4555)).xx;
        float2 _4561 = float2(_4560.x ? 0.0f.xx.x : _4555.x, _4560.y ? 0.0f.xx.y : _4555.y);
        bool2 _4566 = any(isinf(_4561)).xx;
        float2 _4567 = float2(_4566.x ? 0.0f.xx.x : _4561.x, _4566.y ? 0.0f.xx.y : _4561.y);
        float2 _4573 = float2(-_4567.x, _4567.y);
        float2 _2650 = _3174 * _4354;
        float2 _2654 = _3228 * _4354;
        float2 _4628 = _2650 * 16.0146636962890625f;
        float2 _4638 = float2(int2(clamp(sign(_4628) * ceil(abs(_4628)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4654 = _2654 * 16.0146636962890625f;
        float2 _4664 = float2(int2(clamp(sign(_4654) * ceil(abs(_4654)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5991;
        if (max(max(length(_4638), length(_4664)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5991 = 0.0f;
        }
        else
        {
            _5991 = float(length(_4638 - _4664) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2659 = uint(_5991 > 0.0f);
        float _2671 = length(_2654);
        if (_2671 > 4.0f)
        {
            if (_3238)
            {
                uint _4681;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4681);
            }
        }
        bool _2683 = ((cbFI_pad0 & 2048u) != 0u) && (_2659 != 0u);
        bool _2695;
        if (_2683)
        {
            _2695 = length(_2650 - _2654) < (0.07999999821186065673828125f * max(length(_2650), _2671));
        }
        else
        {
            _2695 = _2683;
        }
        bool _2701 = (_3027 & 2048u) != 0u;
        bool _2709;
        if (_2701)
        {
            _2709 = length(_2650 - _2654) > 2.0f;
        }
        else
        {
            _2709 = _2701;
        }
        uint _6126 = ((_3027 & 4096u) != 0u) ? 1u : (_2709 ? 1u : (_2695 ? 0u : _2659));
        rw_dynamic_mask_tp1[_2085] = float4(clamp(float(_6126 + uint(_3135)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_6126 != 0u)
        {
            if (_3238)
            {
                uint _4700;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4700);
            }
        }
        if (_3135 > 0.0f)
        {
            if (_3238)
            {
                uint _4710;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4710);
            }
        }
        if ((_3027 & 512u) != 0u)
        {
            break;
        }
        bool _2743 = (_3027 & 1024u) != 0u;
        bool _2749;
        if (_2743)
        {
            _2749 = (1.0f - (log((_4398 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) < 0.300000011920928955078125f;
        }
        else
        {
            _2749 = _2743;
        }
        if (_2749)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_2085, 0)).x) + uint(float(_4532 < 0.0f))) > 0u)
        {
            if (_3238)
            {
                uint _4730;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4730);
            }
            break;
        }
        float _4763 = 1.0f - (log((_4398 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _6012;
        if (_4763 == 1.0f)
        {
            _6012 = _4763 + ((float(_2385) * _2392) * 0.100000001490116119384765625f);
        }
        else
        {
            _6012 = _4763;
        }
        float _4753 = 1.10000002384185791015625f - _6012;
        float2 _6013;
        float2 _6014;
        do
        {
            if (_3255)
            {
                _6014 = _4573;
                _6013 = _4573;
                break;
            }
            float2 _4782 = _2398 + _4573;
            float _4818 = ((2.0f * _4782.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4785 = (float2(atan(_4818) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4782.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4818 * _4818))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5881;
            float2 _4867 = clamp((((_5881 + (_4785 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4870 = tan(_4867.x);
            _6014 = _4785;
            _6013 = (((float2(_4870 / cbFI_DeviceToViewDepth.z, (tan(_4867.y) * sqrt(1.0f + (_4870 * _4870))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2398) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _6016;
        int2 _6017;
        uint _6025;
        do
        {
            float2 _4917 = _6013 * _4354;
            float2 _4921 = _6014 * _4354;
            bool _4924 = any(isnan(_4917));
            bool _4931;
            if (!_4924)
            {
                _4931 = any(isinf(_4917));
            }
            else
            {
                _4931 = _4924;
            }
            bool _4938;
            if (!_4931)
            {
                _4938 = any(isnan(_4921));
            }
            else
            {
                _4938 = _4931;
            }
            bool _4945;
            if (!_4938)
            {
                _4945 = any(isinf(_4921));
            }
            else
            {
                _4945 = _4938;
            }
            bool _4951;
            if (!_4945)
            {
                _4951 = isnan(_4753);
            }
            else
            {
                _4951 = _4945;
            }
            bool _4957;
            if (!_4951)
            {
                _4957 = isinf(_4753);
            }
            else
            {
                _4957 = _4951;
            }
            if (_4957)
            {
                _6025 = 0u;
                _6017 = int2(0, 0);
                _6016 = false;
                break;
            }
            float2 _4962 = _4917 * cbFI_Timestep;
            bool _4965 = any(isnan(_4962));
            bool _4972;
            if (!_4965)
            {
                _4972 = any(isinf(_4962));
            }
            else
            {
                _4972 = _4965;
            }
            if (_4972)
            {
                _6025 = 0u;
                _6017 = int2(0, 0);
                _6016 = false;
                break;
            }
            float2 _4979 = _2394 + floor(_4962);
            bool _4982 = any(bool2(_4979.x < 0.0f.xx.x, _4979.y < 0.0f.xx.y));
            bool _4991;
            if (!_4982)
            {
                _4991 = any(bool2(_4979.x >= _4354.x, _4979.y >= _4354.y));
            }
            else
            {
                _4991 = _4982;
            }
            if (_4991)
            {
                _6025 = 0u;
                _6017 = int2(0, 0);
                _6016 = false;
                break;
            }
            float2 _4998 = _4921 * (-1.0f);
            float _5045 = _4998.x * 16.0146636962890625f;
            int _5053 = int(clamp(sign(_5045) * ceil(abs(_5045)), -16383.0f, 16383.0f));
            float _5057 = _4998.y * 16.0146636962890625f;
            int _5065 = int(clamp(sign(_5057) * ceil(abs(_5057)), -16383.0f, 16383.0f));
            int _5072 = abs(_5053);
            int _5074 = abs(_5065);
            int _5078 = clamp(firstbithigh(max(_5072, _5074)), 0, 15);
            int _5081 = max((_5078 - 6), 0);
            _6025 = (((((uint((int(round(_4753 * 1860.9090576171875f)) & 2047) << 20) | uint((_5078 & 15) << 16)) | uint(int(_5053 < 0) << 15)) | uint(int(_5065 < 0) << 14)) | uint((clamp(_5072 >> _5081, 0, 127) & 127) << 7)) | uint(clamp(_5074 >> _5081, 0, 127) & 127)) & 2147483647u;
            _6017 = int2(_4979);
            _6016 = true;
            break;
        } while(false);
        if (_6016)
        {
            uint _5163;
            InterlockedMax(rw_warped_motion_qdata_tp1[_6017], _6025, _5163);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _6033 = 0; _6033 < 3; _6033++)
                {
                    int2 _2798 = _6017 + _1457[_6033];
                    if (all(bool2(_2798.x < cbFI_MvDepthLaneSize.x, _2798.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _5168;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2798], _6025, _5168);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2820 = _2398 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2825 = _2398 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _5185_dummy_parameter;
                float4 _5192 = r_depth_tm1.Load(int3(int2(floor(_2398 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5185_dummy_parameter))))), 0));
                float _5193 = _5192.x;
                uint _5201_dummy_parameter;
                float4 _5208 = r_depth_tm1.Load(int3(int2(floor(_2820 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5201_dummy_parameter))))), 0));
                float _5209 = _5208.x;
                uint _5217_dummy_parameter;
                float4 _5224 = r_depth_tm1.Load(int3(int2(floor(_2825 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5217_dummy_parameter))))), 0));
                float _5225 = _5224.x;
                float4x4 _6038;
                do
                {
                    float4x4 _5231;
                    bool _6037;
                    do
                    {
                        _5231 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_3029)
                        {
                            _6037 = false;
                            break;
                        }
                        uint _5265 = (64u + uint(_2390)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_5265 + 32u) * 4 + 0) != 1u)
                        {
                            _6037 = false;
                            break;
                        }
                        uint _6034;
                        _6034 = 0u;
                        for (; _6034 < 4u; _6034++)
                        {
                            for (uint _6035 = 0u; _6035 < 4u; )
                            {
                                _5231[_6034][_6035] = asfloat(rw_nfru_diagnostics.Load<uint>((((_5265 + 16u) + (_6034 * 4u)) + _6035) * 4 + 0));
                                _6035++;
                                continue;
                            }
                        }
                        _6037 = true;
                        break;
                    } while(false);
                    if (_6037)
                    {
                        _6038 = _5231;
                        break;
                    }
                    _6038 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float _5342 = _2820.x;
                float2 _5346 = float2(_5342, 1.0f - _2820.y);
                float4 _5357 = mul(float4((_5346 * 2.0f) - 1.0f.xx, _5209, 1.0f), _6038);
                float _5359 = _5357.w;
                float2 _5373 = _5346 - (((_5357.xy / _5359.xx) + 1.0f.xx) * 0.5f);
                float2 _5375 = abs(_5373);
                bool2 _5381 = all(bool2(_5375.x < 9.9999997473787516355514526367188e-06f.xx.x, _5375.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _5382 = float2(_5381.x ? 0.0f.xx.x : _5373.x, _5381.y ? 0.0f.xx.y : _5373.y);
                bool2 _5387 = any(isnan(_5382)).xx;
                float2 _5388 = float2(_5387.x ? 0.0f.xx.x : _5382.x, _5387.y ? 0.0f.xx.y : _5382.y);
                bool2 _5393 = any(isinf(_5388)).xx;
                float2 _5394 = float2(_5393.x ? 0.0f.xx.x : _5388.x, _5393.y ? 0.0f.xx.y : _5388.y);
                float4x4 _6043;
                do
                {
                    float4x4 _5405;
                    bool _6042;
                    do
                    {
                        _5405 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_3029)
                        {
                            _6042 = false;
                            break;
                        }
                        uint _5439 = (64u + uint(_2390)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_5439 + 32u) * 4 + 0) != 1u)
                        {
                            _6042 = false;
                            break;
                        }
                        uint _6039;
                        _6039 = 0u;
                        for (; _6039 < 4u; _6039++)
                        {
                            for (uint _6040 = 0u; _6040 < 4u; )
                            {
                                _5405[_6039][_6040] = asfloat(rw_nfru_diagnostics.Load<uint>((((_5439 + 16u) + (_6039 * 4u)) + _6040) * 4 + 0));
                                _6040++;
                                continue;
                            }
                        }
                        _6042 = true;
                        break;
                    } while(false);
                    if (_6042)
                    {
                        _6043 = _5405;
                        break;
                    }
                    _6043 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float _5518 = _2825.y;
                float2 _5520 = float2(_2825.x, 1.0f - _5518);
                float4 _5531 = mul(float4((_5520 * 2.0f) - 1.0f.xx, _5225, 1.0f), _6043);
                float _5533 = _5531.w;
                float2 _5547 = _5520 - (((_5531.xy / _5533.xx) + 1.0f.xx) * 0.5f);
                float2 _5549 = abs(_5547);
                bool2 _5555 = all(bool2(_5549.x < 9.9999997473787516355514526367188e-06f.xx.x, _5549.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _5556 = float2(_5555.x ? 0.0f.xx.x : _5547.x, _5555.y ? 0.0f.xx.y : _5547.y);
                bool2 _5561 = any(isnan(_5556)).xx;
                float2 _5562 = float2(_5561.x ? 0.0f.xx.x : _5556.x, _5561.y ? 0.0f.xx.y : _5556.y);
                bool2 _5567 = any(isinf(_5562)).xx;
                float2 _5568 = float2(_5567.x ? 0.0f.xx.x : _5562.x, _5567.y ? 0.0f.xx.y : _5562.y);
                bool _2847 = (_5342 < 1.0f) && (float(_5359 < 0.0f) == 0.0f);
                bool _2853;
                if (_2847)
                {
                    _2853 = abs(_5193 - _5209) <= ((0.0500000007450580596923828125f * max(abs(_5193), abs(_5209))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2853 = _2847;
                }
                bool _2859 = (_5518 < 1.0f) && (float(_5533 < 0.0f) == 0.0f);
                bool _2865;
                if (_2859)
                {
                    _2865 = abs(_5193 - _5225) <= ((0.0500000007450580596923828125f * max(abs(_5193), abs(_5225))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2865 = _2859;
                }
                float2 _5616 = (_2398 + (_4573 * cbFI_Timestep)) * _4354;
                float2 _6044;
                if (_2853)
                {
                    _6044 = ((_2820 + (float2(-_5394.x, _5394.y) * cbFI_Timestep)) * _4354) - _5616;
                }
                else
                {
                    _6044 = float2(1.0f, 0.0f);
                }
                float2 _6045;
                if (_2865)
                {
                    _6045 = ((_2825 + (float2(-_5568.x, _5568.y) * cbFI_Timestep)) * _4354) - _5616;
                }
                else
                {
                    _6045 = float2(0.0f, 1.0f);
                }
                bool _5670 = any(isnan(_6044));
                bool _5677;
                if (!_5670)
                {
                    _5677 = any(isinf(_6044));
                }
                else
                {
                    _5677 = _5670;
                }
                bool2 _6127 = _5677.xx;
                float2 _6128 = float2(_6127.x ? float2(1.0f, 0.0f).x : _6044.x, _6127.y ? float2(1.0f, 0.0f).y : _6044.y);
                bool _5682 = any(isnan(_6045));
                bool _5689;
                if (!_5682)
                {
                    _5689 = any(isinf(_6045));
                }
                else
                {
                    _5689 = _5682;
                }
                bool2 _6129 = _5689.xx;
                float2 _6130 = float2(_6129.x ? float2(0.0f, 1.0f).x : _6045.x, _6129.y ? float2(0.0f, 1.0f).y : _6045.y);
                int2 _5705 = int2(clamp(floor(min(0.0f.xx, _6128) + min(0.0f.xx, _6130)), (-3.0f).xx, 0.0f.xx));
                int2 _5711 = int2(clamp(ceil(max(0.0f.xx, _6128) + max(0.0f.xx, _6130)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5719 = _5705.y;
                for (int _6091 = _5719; _6091 <= _5711.y; _6091++)
                {
                    int _5728 = _5705.x;
                    for (int _6092 = _5728; _6092 <= _5711.x; _6092++)
                    {
                        if ((_6092 == 0) && (_6091 == 0))
                        {
                            continue;
                        }
                        int2 _5747 = _6017 + int2(_6092, _6091);
                        bool _5750 = all(bool2(_5747.x >= int2(0, 0).x, _5747.y >= int2(0, 0).y));
                        bool _5757;
                        if (_5750)
                        {
                            _5757 = all(bool2(_5747.x < cbFI_MvDepthLaneSize.x, _5747.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5757 = _5750;
                        }
                        if (_5757)
                        {
                            uint _5775;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5747], _6025, _5775);
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
