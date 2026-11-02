                                                                                                                     
                                                       
#ifdef MLOF2_EPI_REG
                                                                                                                    
                                                                                                                     
                                                                                                                     
                                                                                                                      
                     
int32_t epi8(const in uint32_t r, const in uint32_t c, const in int32_t x, const in uint32_t ocb, const in uint32_t ocend,
             const in uint32_t so, const in uint32_t bo, const in int32_t act_, const in float inv, const in uint32_t rfmt,
             const in uint32_t rmode, const in uint32_t rbase, const in uint32_t rpx, const in float rscale) {
    uint oc = ocb + c;                                                          
    if (oc >= ocend) return 0;                                                                     
    float y = float(x) * uintBitsToFloat(blob[so + oc]) + uintBitsToFloat(blob[bo + oc]);
    float rr = 0.0;
    if (rfmt != 0xFu) {
        if (rfmt == 2u) {
            uint a = rbase + r * rpx + oc;
            rr = float(bitfieldExtract(int(arena_u32[a >> 2u]), int((a & 3u) * 8u), 8)) * rscale;
        } else if (rfmt == 1u) {
            uint a = rbase + r * rpx + oc * 2u;
            rr = unpackHalf2x16(arena_u32[a >> 2u])[(a >> 1u) & 1u];
        } else {
            rr = uintBitsToFloat(arena_u32[(rbase + r * rpx + oc * 4u) >> 2u]);
        }
        if (rmode != 0u) y += rr;
    }
    y = act_ == 1 ? leaky(y) : (act_ == 2 ? max(y, 0.0) : y);
    if (rfmt != 0xFu && rmode == 0u) y += rr;
    return int32_t(clamp(roundEven(y * inv), -127.0, 127.0));
}
                                                                                                          
float epiAct(const in uint32_t r, const in uint32_t c, const in float x, const in int32_t act_) {
    return act_ == 1 ? leaky(x) : (act_ == 2 ? max(x, 0.0) : x);
}
float epiQ(const in uint32_t r, const in uint32_t c, const in float x, const in uint32_t ocb, const in uint32_t ocend, const in float inv) {
    return ocb + c >= ocend ? 0.0 : clamp(roundEven(x * inv), -127.0, 127.0);                                
}
                                                          
float epiQT(const in uint32_t r, const in uint32_t c, const in float x, const in uint32_t ocb, const in uint32_t ocend, const in float inv) {
    return ocb + r >= ocend ? 0.0 : clamp(roundEven(x * inv), -127.0, 127.0);
}
                                                                                                                    
float epiQB(const in uint32_t r, const in uint32_t c, const in float x, const in uint32_t ocb, const in uint32_t ocend, const in float inv,
            const in uint32_t x0, const in uint32_t w_) {
    return (ocb + r >= ocend || x0 + c >= w_) ? 0.0 : clamp(roundEven(x * inv), -127.0, 127.0);
}
float epiZT(const in uint32_t r, const in uint32_t c, const in float x, const in uint32_t ocb, const in uint32_t ocend) {
    return ocb + r >= ocend ? 0.0 : x;
}
float epiZ(const in uint32_t r, const in uint32_t c, const in float x, const in uint32_t ocb, const in uint32_t ocend) {
    return ocb + c >= ocend ? 0.0 : x;
}
                                                                                      
float epif(const in uint32_t r, const in uint32_t c, const in float x, const in uint32_t ocb, const in uint32_t ocend,
           const in uint32_t so, const in uint32_t bo, const in int32_t act_, const in uint32_t rfmt,
           const in uint32_t rmode, const in uint32_t rbase, const in uint32_t rpx, const in float rscale) {
    uint oc = ocb + c;
    if (oc >= ocend) return 0.0;
    float y = x * uintBitsToFloat(blob[so + oc]) + uintBitsToFloat(blob[bo + oc]);
    float rr = 0.0;
    if (rfmt != 0xFu) {
        if (rfmt == 2u) {
            uint a = rbase + r * rpx + oc;
            rr = float(bitfieldExtract(int(arena_u32[a >> 2u]), int((a & 3u) * 8u), 8)) * rscale;
        } else if (rfmt == 1u) {
            uint a = rbase + r * rpx + oc * 2u;
            rr = unpackHalf2x16(arena_u32[a >> 2u])[(a >> 1u) & 1u];
        } else {
            rr = uintBitsToFloat(arena_u32[(rbase + r * rpx + oc * 4u) >> 2u]);
        }
        if (rmode != 0u) y += rr;
    }
    y = act_ == 1 ? leaky(y) : (act_ == 2 ? max(y, 0.0) : y);
    if (rfmt != 0xFu && rmode == 0u) y += rr;
    return y;
}
#endif
