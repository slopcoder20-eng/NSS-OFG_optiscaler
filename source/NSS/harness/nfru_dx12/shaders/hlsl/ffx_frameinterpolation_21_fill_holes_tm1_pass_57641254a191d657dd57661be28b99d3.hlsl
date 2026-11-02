static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _377[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _387[5] = { 2, 4, 7, 11, 16 };

cbuffer cbFI_t : register(b2, space0)
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

RWByteAddressBuffer rw_nfru_diagnostics : register(u3, space0);
Texture2D<uint4> r_warped_flow_qdata_tm1 : register(t0, space0);
RWTexture2D<float2> rw_warped_filled_flow_tm1 : register(u1, space0);

static uint3 gl_GlobalInvocationID;
struct SPIRV_Cross_Input
{
    uint3 gl_GlobalInvocationID : SV_DispatchThreadID;
};

void comp_main()
{
    int2 _477 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_477.x >= cbFI_FlowLaneSize.x, _477.y >= cbFI_FlowLaneSize.y)))
        {
            break;
        }
        uint _535[9];
        _535[0] = r_warped_flow_qdata_tm1.Load(int3(_477, 0)).x;
        _535[1] = r_warped_flow_qdata_tm1.Load(int3(_477 + int2(1, 0), 0)).x;
        _535[2] = r_warped_flow_qdata_tm1.Load(int3(_477 + int2(0, 1), 0)).x;
        _535[3] = r_warped_flow_qdata_tm1.Load(int3(_477 + int2(0, -1), 0)).x;
        _535[4] = r_warped_flow_qdata_tm1.Load(int3(_477 + int2(-1, 0), 0)).x;
        _535[5] = r_warped_flow_qdata_tm1.Load(int3(_477 + int2(-1, 1), 0)).x;
        _535[6] = r_warped_flow_qdata_tm1.Load(int3(_477 + int2(1, 1), 0)).x;
        _535[7] = r_warped_flow_qdata_tm1.Load(int3(_477 + int2(-1, -1), 0)).x;
        _535[8] = r_warped_flow_qdata_tm1.Load(int3(_477 + int2(1, -1), 0)).x;
        uint _947;
        _947 = _535[0];
        uint _969;
        for (int _946 = 1; _946 < 9; _947 = _969, _946++)
        {
            _969 = (_535[_946] > _947) ? _535[_946] : _947;
        }
        bool _621 = _947 == 0u;
        bool _628;
        if (_621)
        {
            _628 = (cbFI_pad0 & 536870912u) != 0u;
        }
        else
        {
            _628 = _621;
        }
        uint _950;
        if (_628)
        {
            uint _949;
            _949 = 4294967295u;
            uint _965;
            for (int _948 = 0; _948 < 8; _949 = _965, _948++)
            {
                int _956 = 0;
                for (;;)
                {
                    if (_956 < 5)
                    {
                        int2 _649 = _477 + (_377[_948] * _387[_956].xx);
                        bool _652 = any(bool2(_649.x < int2(0, 0).x, _649.y < int2(0, 0).y));
                        bool _660;
                        if (!_652)
                        {
                            _660 = any(bool2(_649.x >= cbFI_FlowLaneSize.x, _649.y >= cbFI_FlowLaneSize.y));
                        }
                        else
                        {
                            _660 = _652;
                        }
                        if (_660)
                        {
                            _965 = _949;
                            break;
                        }
                        uint4 _807 = r_warped_flow_qdata_tm1.Load(int3(_649, 0));
                        uint _808 = _807.x;
                        if (_808 != 0u)
                        {
                            _965 = min(_949, _808);
                            break;
                        }
                        _956++;
                        continue;
                    }
                    else
                    {
                        _965 = _949;
                        break;
                    }
                }
            }
            bool _681 = _949 != 4294967295u;
            if (_681)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _817;
                    rw_nfru_diagnostics.InterlockedAdd(252, 1u, _817);
                }
            }
            _950 = _681 ? _949 : _947;
        }
        else
        {
            _950 = _947;
        }
        if ((cbFI_pad0 & 1024u) != 0u)
        {
            rw_nfru_diagnostics.Store<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_477.y * cbFI_FlowLaneSize.x) + _477.x)) * 4 + 0, uint(_950 != 0u));
        }
        uint _879 = _950 & 2147483647u;
        uint _911 = uint(max((int((_879 >> 16u) & 15u) - 6), 0));
        rw_warped_filled_flow_tm1[_477] = float4((float2(float((1 - (2 * int((_879 >> 15u) & 1u))) * int(((_879 >> uint(7)) & 127u) << _911)), float((1 - (2 * int((_879 >> 14u) & 1u))) * int((_879 & 127u) << _911))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp, 0.0f, 0.0f).xy;
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
