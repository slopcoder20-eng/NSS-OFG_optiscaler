struct InputTensorPacked_t
{
    uint rgbM1MV_rP1MV;
    uint gbP1MV_rgM1OF;
    uint bM1OF_rgbP1OF;
    uint depth_disMask;
};

static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

cbuffer cbFI_t : register(b3, space0)
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

ByteAddressBuffer r_in_tensor : register(t1, space0);
Texture2D<float4> r_dynamic_mask_tp1 : register(t5, space0);
Texture2D<float4> r_current_interpolation_source : register(t4, space0);
SamplerState s_LinearClamp : register(s1001, space0);
RWTexture2D<float3> rw_output : register(u2, space0);

static uint3 gl_GlobalInvocationID;
struct SPIRV_Cross_Input
{
    uint3 gl_GlobalInvocationID : SV_DispatchThreadID;
};

uint spvBitfieldUExtract(uint Base, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : ((1 << Count) - 1);
    return (Base >> Offset) & Mask;
}

uint2 spvBitfieldUExtract(uint2 Base, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : ((1 << Count) - 1);
    return (Base >> Offset) & Mask;
}

uint3 spvBitfieldUExtract(uint3 Base, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : ((1 << Count) - 1);
    return (Base >> Offset) & Mask;
}

uint4 spvBitfieldUExtract(uint4 Base, uint Offset, uint Count)
{
    uint Mask = Count == 32 ? 0xffffffff : ((1 << Count) - 1);
    return (Base >> Offset) & Mask;
}

int spvBitfieldSExtract(int Base, int Offset, int Count)
{
    int Mask = Count == 32 ? -1 : ((1 << Count) - 1);
    int Masked = (Base >> Offset) & Mask;
    int ExtendShift = (32 - Count) & 31;
    return (Masked << ExtendShift) >> ExtendShift;
}

int2 spvBitfieldSExtract(int2 Base, int Offset, int Count)
{
    int Mask = Count == 32 ? -1 : ((1 << Count) - 1);
    int2 Masked = (Base >> Offset) & Mask;
    int ExtendShift = (32 - Count) & 31;
    return (Masked << ExtendShift) >> ExtendShift;
}

int3 spvBitfieldSExtract(int3 Base, int Offset, int Count)
{
    int Mask = Count == 32 ? -1 : ((1 << Count) - 1);
    int3 Masked = (Base >> Offset) & Mask;
    int ExtendShift = (32 - Count) & 31;
    return (Masked << ExtendShift) >> ExtendShift;
}

int4 spvBitfieldSExtract(int4 Base, int Offset, int Count)
{
    int Mask = Count == 32 ? -1 : ((1 << Count) - 1);
    int4 Masked = (Base >> Offset) & Mask;
    int ExtendShift = (32 - Count) & 31;
    return (Masked << ExtendShift) >> ExtendShift;
}

void comp_main()
{
    int2 _472 = int2(gl_GlobalInvocationID.xy);
    do
    {
        int2 _547 = cbFI_DisplaySize / int2(3, 3);
        int _552 = _472.x / _547.x;
        int _557 = _472.y / _547.y;
        if ((_552 >= 3) || (_557 >= 3))
        {
            rw_output[_472] = float4(0.0f, 0.0f, 0.0f, 1.0f).xyz;
            break;
        }
        uint _744;
        int4 _796;
        float2 _580 = (float2(_472 - (int2(_552, _557) * _547)) + 0.5f.xx) / float2(_547);
        uint2 _591 = uint2(clamp(int2(_580 * float2(cbFI_InputTensorSize)), int2(0, 0), cbFI_InputTensorSize - int2(1, 1)));
        do
        {
            _744 = (_591.y * uint(cbFI_InputTensorSize.x)) + _591.x;
            int _785 = int(r_in_tensor.Load<uint>(_744 * 16 + 0));
            _796 = int4(spvBitfieldSExtract(_785, 0, 8), spvBitfieldSExtract(_785, 8, 8), spvBitfieldSExtract(_785, 16, 8), spvBitfieldSExtract(_785, 24, 8));
            break;
        } while(false);
        int4 _946;
        float _595 = 1.0f / cbFI_QuantParamsSINT.x;
        float4 _856 = cbFI_QuantParamsSINT.y.xxxx;
        float4 _860 = (float4(_796) - _856) * _595;
        do
        {
            int _935 = int(r_in_tensor.Load<uint>(_744 * 16 + 4));
            _946 = int4(spvBitfieldSExtract(_935, 0, 8), spvBitfieldSExtract(_935, 8, 8), spvBitfieldSExtract(_935, 16, 8), spvBitfieldSExtract(_935, 24, 8));
            break;
        } while(false);
        int4 _1096;
        float4 _995 = (float4(_946) - _856) * _595;
        do
        {
            int _1085 = int(r_in_tensor.Load<uint>(_744 * 16 + 8));
            _1096 = int4(spvBitfieldSExtract(_1085, 0, 8), spvBitfieldSExtract(_1085, 8, 8), spvBitfieldSExtract(_1085, 16, 8), spvBitfieldSExtract(_1085, 24, 8));
            break;
        } while(false);
        int4 _1246;
        float4 _1130 = (float4(_1096) - _856) * _595;
        do
        {
            int _1235 = int(r_in_tensor.Load<uint>(_744 * 16 + 12));
            _1246 = int4(spvBitfieldSExtract(_1235, 0, 8), spvBitfieldSExtract(_1235, 8, 8), spvBitfieldSExtract(_1235, 16, 8), spvBitfieldSExtract(_1235, 24, 8));
            break;
        } while(false);
        float4 _1265 = (float4(_1246) - _856) * _595;
        float4 _1352;
        switch ((_557 * 3) + _552)
        {
            case 0:
            {
                _1352 = float4(_1265.x, 0.0f, 0.0f, 1.0f);
                break;
            }
            case 1:
            {
                _1352 = float4(_1265.y, 0.0f, 0.0f, 1.0f);
                break;
            }
            case 2:
            {
                _1352 = float4(_1265.z, 0.0f, 0.0f, 1.0f);
                break;
            }
            case 3:
            {
                _1352 = float4(_1265.w, 0.0f, 0.0f, 1.0f);
                break;
            }
            case 4:
            {
                _1352 = float4(_860.xyz, 1.0f);
                break;
            }
            case 5:
            {
                _1352 = float4(_860.w, _995.xy, 1.0f);
                break;
            }
            case 6:
            {
                _1352 = float4(_995.zw, _1130.x, 1.0f);
                break;
            }
            case 7:
            {
                _1352 = float4(_1130.yzw, 1.0f);
                break;
            }
            case 8:
            {
                _1352 = float4(lerp(r_current_interpolation_source.SampleLevel(s_LinearClamp, _580, 0.0f).xyz, float3(0.5f, 0.5f, 0.0f), (0.4000000059604644775390625f * r_dynamic_mask_tp1.Load(int3(clamp(int2(_580 * float2(cbFI_MvDepthLaneSize)), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x).xxx), 1.0f);
                break;
            }
            default:
            {
                _1352 = float4(0.0f, 0.0f, 0.0f, 1.0f);
                break;
            }
        }
        rw_output[_472] = _1352.xyz;
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
