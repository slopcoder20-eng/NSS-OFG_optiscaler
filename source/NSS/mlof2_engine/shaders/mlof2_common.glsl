                                                                                            
                                                               
                                                                                                                 
                                                                                                                  
                                                                                      
                                                                                                                 

layout(push_constant) uniform PushConstants {
    uint op;                   
    uint tb;                                                                                                     
    uint sb;                                                                   
    uint ob;                                                       
    uint fc;                                                                                                          
} pc;

layout(std430, set = 0, binding = 0) buffer Arena { uint arena_u32[]; };
#ifdef MLOF2_DX                                                                     
uvec4 ldv4(uint i) { return uvec4(arena_u32[4u * i], arena_u32[4u * i + 1u], arena_u32[4u * i + 2u], arena_u32[4u * i + 3u]); }
uvec2 ldv2(uint i) { return uvec2(arena_u32[2u * i], arena_u32[2u * i + 1u]); }
void stv2(uint i, uvec2 v) { arena_u32[2u * i] = v.x; arena_u32[2u * i + 1u] = v.y; }
void stv4(uint i, uvec4 v) { arena_u32[4u * i] = v.x; arena_u32[4u * i + 1u] = v.y; arena_u32[4u * i + 2u] = v.z; arena_u32[4u * i + 3u] = v.w; }
#else
layout(std430, set = 0, binding = 0) buffer ArenaV2 { uvec2 arena_v2[]; };                                 
uvec2 ldv2(uint i) { return arena_v2[i]; }
void stv2(uint i, uvec2 v) { arena_v2[i] = v; }
layout(std430, set = 0, binding = 0) buffer ArenaV { uvec4 arena_v4[]; };                                   
uvec4 ldv4(uint i) { return arena_v4[i]; }
void stv4(uint i, uvec4 v) { arena_v4[i] = v; }
#endif
layout(std430, set = 0, binding = 1) readonly buffer Blob { uint blob[]; };
#ifndef MLOF2_DX
layout(std430, set = 0, binding = 1) readonly buffer BlobV { uvec4 blob_v4[]; };
uvec4 ldb4(uint i) { return blob_v4[i]; }
#else
uvec4 ldb4(uint i) { return uvec4(blob[4u * i], blob[4u * i + 1u], blob[4u * i + 2u], blob[4u * i + 3u]); }
#endif
layout(std430, set = 0, binding = 2) readonly buffer Meta { uint meta[]; };

            
#define OP_KIND 0
#define OP_OUT 1
#define OP_OUT_COFF 2
#define OP_OUT_C 3
#define OP_SEG0 4
#define OP_NSEG 5
#define OP_IP 6                 
#define OP_FP 14                  
#define OP_W_OFF 18
#define OP_KW_WORDS 19
#define OP_SCALE_OFF 20
#define OP_BIAS_OFF 21

#define K_CONV 0
#define K_UNSHUFFLE 1
#define K_RESIZE_AREA 2
#define K_RESIZE_BIL 3
#define K_WARP 4
#define K_CORR 5
#define K_ABSDIFF 6
#define K_ROUND_TRIP 7
#define K_SPREAD 8
#define K_AXPY 9
#define K_SCALE 10
#define K_ZEROS 11
#define K_COPY 12
#define K_CONVEX_UP 13
#define K_PROP_STEP 14
                                                                            
#define K_VIG_PART 15
#define K_VIG_SOLVE 16
#define K_VIG_APPLY 17
#define K_MUL 18
#define K_INVERT_T 19
#define K_WARP_NOISE 20
#define K_OFF_FRAME 21
#define K_FLOWDIST 22
#define K_SIGMOID 23
#define K_FILL_T 24
#define K_UP_NEAREST 25
#define K_SOFTMAX_BLEND 26
#define K_RULE_PREP 27
#define K_POOL 28
#define K_LUMA_GRAD 29
#define K_MASK_MUL 30
#define K_MEDIAN 31
#define K_RULE_SCORE 32
#define K_AXPY_T 33
#define K_RULE_CARRY 34
#define K_BLEND_MASK 35
#define K_CAM_FLOW 36
#define K_TRAIL_SEL 37
#define K_WARP_NOISE4 38
#define K_FEAT4 39
#define K_MEDIAN_HIST 40
#define K_MEDIAN_PICK 41
#define K_PREP_C 42
#define K_PREP_F 43
#define K_BLEND_PREP 44
#define K_CARRY 45
#define K_CAM_INV 46
#define K_FINAL 47
#define K_PREP 48
#define K_INV3 49
#define K_FEAT4C 50
#define K_BLEND9 51
#define K_FINAL3 52
#define K_PREP_H 53
#define K_Q_PREP 54
#define K_Q_CAND 55
#define K_Q_FEAT 56
#define K_Q_RULE1 57
#define K_Q_RULE2 58
#define K_CAM_INV_Q 59
#define K_FINAL4 60
#define K_HOMOG_ACC 61
#define K_HOMOG_SOLVE 62
#define K_DEPTHWISE 63
#define K_OFT_INIT 64
#define K_OFT_PREP 65
#define K_OFT_OUT 66
#define K_OFT_FINAL 67
#define K_OFT_LK 68
#define K_OFT_LUMA 69
#define K_FUSE_PREP 70
#define K_FUSE_BLEND 71

                                         
#define FC_T 0
#define FC_HAS_PREV 1
#define FC_PAIR_FIRST 2
#define FC_TRAIL_HOMOG_AUTO 3
#define FC_FORCE_HOMOG 52
#define FC_VP_A 4
#define FC_VP_B 20
#define FC_INV_VP_A 36
                                                                                                                 
                                                                                          
#define FC_OFG_DEBUG 52                                                                                                              
#define FC_EXT_DISP_W 55
#define FC_EXT_DISP_H 56
#define FC_EXT_MV_W 57                         
#define FC_EXT_MV_H 58
#define FC_EXT_DEP_W 59                           
#define FC_EXT_DEP_H 60
#define FC_EXT_REVZ 61
#define FC_EXT_MVAP 62                                                                                           
#define FC_EXT_MVAP_OFF 63
#define FC_EXT_IN 53                                                                                               
#define FC_EXT_SNAP_W 54                                                                                  
#define FC_EXT_MV_SX 64                                                        
#define FC_EXT_MV_SY 65
#define FC_EXT_OUT 67                                                                                         
#define FC_EXT_HUD 68                                                                                      
#define FC_EXT_OF 66                                                                                                    

float fcf(uint i) { return uintBitsToFloat(meta[pc.fc + i]); }

struct Tensor {
    uint base;                             
    uint c;
    uint w;
    uint h;
    uint n;
    uint s;
    uint fmt;                                              
    uint c_alloc;                                                              
    float scale;                                                 
};

uint opw(uint i) { return meta[pc.ob + pc.op * 24u + i]; }
                                                                                                              
                                                                                                        
#ifndef MLOF2_DX
layout(constant_id = 1) const int MLOF2_IP0 = 0x7FFFFFFF;
layout(constant_id = 2) const int MLOF2_IP1 = 0x7FFFFFFF;
#else
const int MLOF2_IP0 = 0x7FFFFFFF;
const int MLOF2_IP1 = 0x7FFFFFFF;
#endif
int  opi(uint i) {
    if (i == 0u && MLOF2_IP0 != 0x7FFFFFFF) return MLOF2_IP0;
    if (i == 1u && MLOF2_IP1 != 0x7FFFFFFF) return MLOF2_IP1;
    return int(meta[pc.ob + pc.op * 24u + OP_IP + i]);
}
float opf(uint i) { return uintBitsToFloat(meta[pc.ob + pc.op * 24u + OP_FP + i]); }

Tensor tensorAt(uint t) {
    uint b = pc.tb + t * 8u;
    Tensor r;
    r.base = meta[b];
    r.c = meta[b + 1u];
    r.w = meta[b + 2u];
    r.h = meta[b + 3u];
    r.n = meta[b + 4u];
    r.s = meta[b + 5u];
    uint f_ca = meta[b + 6u];
    r.fmt = f_ca & 0xFFu;
    r.c_alloc = (f_ca >> 8u) & 0xFFFFu;
    r.scale = uintBitsToFloat(meta[b + 7u]);
    return r;
}

                                                                                                                      
                                                                                                                    
                                                                                                                 
#ifndef MLOF2_DX
layout(constant_id = 0) const uint MLOF2_SFMT = 0xFFFFFFFFu;
#else
const uint MLOF2_SFMT = 0xFFFFFFFFu;
#endif
uint sfmt(uint i, uint f) { uint s = (MLOF2_SFMT >> (4u * i)) & 0xFu; return s == 0xFu ? f : s; }
Tensor outAt() { Tensor t = tensorAt(opw(OP_OUT)); t.fmt = sfmt(7u, t.fmt); return t; }

                                                                         
struct Seg { Tensor t; uint c_off; uint c; bool swap; };
Seg segAt(uint i) {
    uint b = pc.sb + (opw(OP_SEG0) + i) * 4u;
    Seg s;
    s.t = tensorAt(meta[b]);
    if (i < 7u) s.t.fmt = sfmt(i, s.t.fmt);
    s.c_off = meta[b + 1u];
    s.c = meta[b + 2u];
    s.swap = meta[b + 3u] != 0u;
    return s;
}

uint srcRow(Seg s, uint row) { return s.swap ? (1u - row) : row; }

                                              
uint tensorByteAddr(Tensor t, uint row, int y, int x, uint c) {
    uint esz = (t.fmt == 0u) ? 4u : ((t.fmt == 1u) ? 2u : 1u);
    return t.base + (((row * t.h + uint(y)) * t.w + uint(x)) * t.c_alloc + c) * esz;
}

                                               
uint segByteAddr(Seg s, uint row, int y, int x, uint c) {
    return tensorByteAddr(s.t, srcRow(s, row), y, x, s.c_off + c);
}

                                           
float decode_fp8(uint b) {
    uint s = (b >> 7u) & 1u;
    uint e = (b >> 3u) & 0xFu;
    uint m = b & 7u;
    if (e == 0xFu && m == 7u) return 0.0;
    float val;
    if (e == 0u) {
        val = float(m) * (1.0 / 512.0);                           
    } else {
        val = (1.0 + float(m) * 0.125) * exp2(float(e) - 7.0);
    }
    return s != 0u ? -val : val;
}

                                                                                                            
uint encode_fp8(float v) {
    if (isnan(v)) return 0x7Fu;
    uint s = v < 0.0 ? 0x80u : 0u;
    float av = min(abs(v), 448.0);
    int e = max(int(floor(log2(max(av, 1e-30)))), -6);                                             
    if (exp2(float(e)) > av && e > -6) e -= 1;                                                  
    else if (exp2(float(e + 1)) <= av) e += 1;
    float m = roundEven(av * exp2(float(3 - e)));                                                         
    if (m >= 16.0) { e += 1; m = 8.0; }
    if (m < 8.0) return s | uint(m);                                                   
    return s | (uint(e + 7) << 3u) | (uint(m) - 8u);
}

                                   
float segRead(Seg s, uint row, int y, int x, uint c) {
    uint addr = segByteAddr(s, row, y, x, c);
    uint u32_idx = addr >> 2u;
    if (s.t.fmt == 0u) {        
        return uintBitsToFloat(arena_u32[u32_idx]);
    } else if (s.t.fmt == 1u) {        
        uint w = arena_u32[u32_idx];
        uint shift = (addr & 2u) * 8u;
        return unpackHalf2x16(w)[(addr >> 1u) & 1u];
    } else if (s.t.fmt == 2u) {        
        uint w = arena_u32[u32_idx];
        int code = bitfieldExtract(int(w), int((addr & 3u) * 8u), 8);
        return float(code) * s.t.scale;
    } else {              
        uint w = arena_u32[u32_idx];
        uint code = uint(bitfieldExtract(int(w), int((addr & 3u) * 8u), 8)) & 0xFFu;
        return decode_fp8(code) * s.t.scale;
    }
}

                      
float decode8(Tensor t, uint code) {
    return t.fmt == 2u ? float(int(code << 24u) >> 24) * t.scale : decode_fp8(code & 0xFFu) * t.scale;
}

                                                                                                     
                                                                                             
bool seg4h(Seg s, uint c) { return s.t.fmt == 1u && ((s.c_off + c) & 3u) == 0u && (s.t.c_alloc & 3u) == 0u && (s.t.base & 7u) == 0u; }
vec4 segLd4h(Seg s, uint row, int y, int x, uint c) {
    uvec2 w = ldv2(segByteAddr(s, row, y, x, c) >> 3u);
    return vec4(unpackHalf2x16(w.x), unpackHalf2x16(w.y));
}
vec2 segRead2(Seg s, uint row, int y, int x, uint c) {
    uint addr = segByteAddr(s, row, y, x, c);
    uint u32_idx = addr >> 2u;
    if (s.t.fmt == 1u && (c & 1u) == 0u) {
        return unpackHalf2x16(arena_u32[u32_idx]);
    } else if (s.t.fmt == 0u) {
        return vec2(uintBitsToFloat(arena_u32[u32_idx]), uintBitsToFloat(arena_u32[u32_idx + 1u]));
    } else {
        return vec2(segRead(s, row, y, x, c), segRead(s, row, y, x, c + 1u));
    }
}

vec4 segRead4(Seg s, uint row, int y, int x, uint c) {
    if (seg4h(s, c)) return segLd4h(s, row, y, x, c);                                                  
    if (s.t.fmt == 1u && ((s.c_off + c) & 1u) == 0u && (s.t.c_alloc & 1u) == 0u && (s.t.base & 3u) == 0u) {                  
        uint i = segByteAddr(s, row, y, x, c) >> 2u;                                                                        
        return vec4(unpackHalf2x16(arena_u32[i]), unpackHalf2x16(arena_u32[i + 1u]));
    }
    if (s.t.fmt >= 2u && ((s.c_off + c) & 3u) == 0u && (s.t.c_alloc & 3u) == 0u && (s.t.base & 3u) == 0u) {                    
        uint w = arena_u32[segByteAddr(s, row, y, x, c) >> 2u];
        return vec4(decode8(s.t, w), decode8(s.t, w >> 8u), decode8(s.t, w >> 16u), decode8(s.t, w >> 24u));
    }
    uint addr = segByteAddr(s, row, y, x, c);
    if (s.t.fmt == 1u && (addr & 3u) == 0u) {
        uint i = addr >> 2u;
        return vec4(unpackHalf2x16(arena_u32[i]), unpackHalf2x16(arena_u32[i + 1u]));
    }
    if (s.t.fmt >= 2u && (addr & 3u) == 0u) {
        uint w = arena_u32[addr >> 2u];
        return vec4(decode8(s.t, w), decode8(s.t, w >> 8u), decode8(s.t, w >> 16u), decode8(s.t, w >> 24u));
    }
    if (s.t.fmt == 0u) {
        uint i = addr >> 2u;
        return uintBitsToFloat(uvec4(arena_u32[i], arena_u32[i + 1u], arena_u32[i + 2u], arena_u32[i + 3u]));
    }
    return vec4(segRead(s, row, y, x, c), segRead(s, row, y, x, c + 1u), segRead(s, row, y, x, c + 2u), segRead(s, row, y, x, c + 3u));
}

                                  
float tensorRead(Tensor t, uint row, int y, int x, uint c) {
    Seg s; s.t = t; s.c_off = 0u; s.c = t.c; s.swap = false;
    return segRead(s, row, y, x, c);
}


                                                                                                           
float segReadZ(Seg s, uint row, int y, int x, uint c) {
    bool in_ = x >= 0 && y >= 0 && x < int(s.t.w) && y < int(s.t.h);
    float v = segRead(s, row, clamp(y, 0, int(s.t.h) - 1), clamp(x, 0, int(s.t.w) - 1), c);
    return in_ ? v : 0.0;
}

                   
float segReadC(Seg s, uint row, int y, int x, uint c) {
    return segRead(s, row, clamp(y, 0, int(s.t.h) - 1), clamp(x, 0, int(s.t.w) - 1), c);
}

                         
float segBilinearZ(Seg s, uint row, float u, float v, uint c) {
    float x0f = floor(u), y0f = floor(v);
    float ax = u - x0f, ay = v - y0f;
    int x0 = int(x0f), y0 = int(y0f);
    return (1.0 - ay) * ((1.0 - ax) * segReadZ(s, row, y0, x0, c) + ax * segReadZ(s, row, y0, x0 + 1, c)) +
           ay * ((1.0 - ax) * segReadZ(s, row, y0 + 1, x0, c) + ax * segReadZ(s, row, y0 + 1, x0 + 1, c));
}

                                                   
                                                                         
uint segRead4Codes(Seg s, uint row, int y, int x, uint c) {
    if (x < 0 || y < 0 || x >= int(s.t.w) || y >= int(s.t.h)) return 0u;
    uint addr = segByteAddr(s, row, y, x, c);
    return arena_u32[addr >> 2u];
}

                          
void tensorWrite(Tensor t, uint row, int y, int x, uint c, float val) {
    uint addr = tensorByteAddr(t, row, y, x, c);
    uint u32_idx = addr >> 2u;
    if (t.fmt == 0u) {
        arena_u32[u32_idx] = floatBitsToUint(val);
    } else if (t.fmt == 1u) {
        uint h = packHalf2x16(vec2(val, 0.0)) & 0xFFFFu;
        uint shift = (addr & 2u) * 8u;
        uint cur = arena_u32[u32_idx];
        arena_u32[u32_idx] = (cur & ~(0xFFFFu << shift)) | (h << shift);
    } else if (t.fmt == 2u) {
        int code = int(clamp(roundEven(val / t.scale), -127.0, 127.0));
        uint b = uint(code) & 0xFFu;
        uint shift = (addr & 3u) * 8u;
        uint cur = arena_u32[u32_idx];
        arena_u32[u32_idx] = (cur & ~(0xFFu << shift)) | (b << shift);
    } else {       
        uint code = encode_fp8(val / t.scale);
        uint shift = (addr & 3u) * 8u;
        uint cur = arena_u32[u32_idx];
        arena_u32[u32_idx] = (cur & ~(0xFFu << shift)) | (code << shift);
    }
}

                                                                        
void tensorWrite4(Tensor t, uint row, int y, int x, uint c0, vec4 val) {
    uint addr = tensorByteAddr(t, row, y, x, c0);
    uint u32_idx = addr >> 2u;
    if (t.fmt == 0u) {
        arena_u32[u32_idx + 0u] = floatBitsToUint(val.x);
        arena_u32[u32_idx + 1u] = floatBitsToUint(val.y);
        arena_u32[u32_idx + 2u] = floatBitsToUint(val.z);
        arena_u32[u32_idx + 3u] = floatBitsToUint(val.w);
    } else if (t.fmt == 1u) {
        arena_u32[u32_idx + 0u] = packHalf2x16(val.xy);
        arena_u32[u32_idx + 1u] = packHalf2x16(val.zw);
    } else if (t.fmt == 2u) {
        ivec4 q = ivec4(clamp(roundEven(val / t.scale), -127.0, 127.0));
        uint packed = (uint(q.x) & 0xFFu) | ((uint(q.y) & 0xFFu) << 8u) |
                      ((uint(q.z) & 0xFFu) << 16u) | ((uint(q.w) & 0xFFu) << 24u);
        arena_u32[u32_idx] = packed;
    } else {       
        uint packed = encode_fp8(val.x / t.scale) | (encode_fp8(val.y / t.scale) << 8u) |
                      (encode_fp8(val.z / t.scale) << 16u) | (encode_fp8(val.w / t.scale) << 24u);
        arena_u32[u32_idx] = packed;
    }
}

                                                                                   
uint encodeBits(Tensor t, float v) {
    if (t.fmt == 0u) return floatBitsToUint(v);
    if (t.fmt == 1u) return packHalf2x16(vec2(v, 0.0)) & 0xFFFFu;
    if (t.fmt == 2u) return uint(int(clamp(roundEven(v / t.scale), -127.0, 127.0))) & 0xFFu;
    return encode_fp8(v / t.scale);
}

                                                                                                             
                                                                                                              
                                                                                                              
uint w_idx = 0xFFFFFFFFu, w_val = 0u, w_mask = 0u;
void wflush() {
    if (w_idx == 0xFFFFFFFFu) return;
    arena_u32[w_idx] = w_mask == 0xFFFFFFFFu ? w_val : ((arena_u32[w_idx] & ~w_mask) | (w_val & w_mask));
    w_idx = 0xFFFFFFFFu;
}
void wput(Tensor t, uint row, int y, int x, uint c, float v) {
    uint addr = tensorByteAddr(t, row, y, x, c);
    uint idx = addr >> 2u, sh = (addr & 3u) * 8u;
    uint m = t.fmt == 0u ? 0xFFFFFFFFu : (t.fmt == 1u ? 0xFFFFu : 0xFFu) << sh;
    if (idx != w_idx) { wflush(); w_idx = idx; w_val = 0u; w_mask = 0u; }
    w_val |= encodeBits(t, v) << sh;
    w_mask |= m;
}
                                                                                                 
void wzeroPad(Tensor t, uint row, int y, int x) {
    if (t.fmt >= 2u) for (uint c = t.c; c < t.c_alloc; ++c) wput(t, row, y, x, c, 0.0);
}

                                                                       
void tensorZeroPad(Tensor t, uint row, int y, int x) {
    if (t.c_alloc > t.c && t.fmt >= 2u) {
        for (uint c = t.c; c < t.c_alloc; ++c) {
            uint addr = tensorByteAddr(t, row, y, x, c);
            uint shift = (addr & 3u) * 8u;
            arena_u32[addr >> 2u] &= ~(0xFFu << shift);                                       
        }
    }
}

float leaky(float x) { return x >= 0.0 ? x : 0.1 * x; }
