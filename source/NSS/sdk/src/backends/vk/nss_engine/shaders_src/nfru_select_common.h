                                                                                     
layout(push_constant) uniform PC {
    uint w, h;                                                              
    uint iw, ih;                                 
    uint c1, c2;                                                                                                             
    uint iw2, ih2;                        
    uint cout, stride, relu, wofs;
    uint fw, fh;                                         
} pc;

vec3 nfruUnpack(uint v)
{
    uint rg = ((v & 0x7ffu) << 4u) | (((v >> 11u) & 0x7ffu) << 20u);
    vec2 c_rg = unpackHalf2x16(rg);
    float c_b = unpackHalf2x16(((v >> 22u) & 0x3ffu) << 5u).x;
    return vec3(c_rg, c_b);
}

                                                                                                   
void nfruLinear(uint dst, uint outSize, uint inSize, out uint i0, out uint i1, out float l)
{
    float s = max((float(dst) + 0.5) * (float(inSize) / float(outSize)) - 0.5, 0.0);
    i0 = min(uint(s), inSize - 1u); i1 = min(i0 + 1u, inSize - 1u); l = s - float(i0);
}
