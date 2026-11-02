#ifndef NFRU_ANGULAR_H
#define NFRU_ANGULAR_H
                                                                                            
                                                                                                                 
                                                                                                       
                                                                             
                                                                                                                        
                                                               
bool NfruAngular() { return (cbFI._pad0 & 0x40000000u) != 0u; }
float2 NfruTanHalfFov() { return float2(cbFI._DeviceToViewDepth[2], cbFI._DeviceToViewDepth[3]); }
float2 NfruToAngle(float2 uv)
{
    float2 k = NfruTanHalfFov();
    float  X = (2.0 * uv.x - 1.0) * k.x, Y = (2.0 * uv.y - 1.0) * k.y;
    return float2(atan(X) / (2.0 * k.x), atan(Y / sqrt(1.0 + X * X)) / (2.0 * k.y)) + 0.5;
}
float2 NfruFromAngle(float2 a)
{
    float2 k = NfruTanHalfFov();
                                                                                  
    float2 c = clamp((a - 0.5) * 2.0 * k, float2(-1.55), float2(1.55));
    float  X = tan(c.x), Y = tan(c.y) * sqrt(1.0 + X * X);
    return float2(X / k.x, Y / k.y) * 0.5 + 0.5;
}
                                                                         
float2 NfruVec(float2 from, float2 to) { return NfruAngular() ? NfruToAngle(to) - NfruToAngle(from) : to - from; }
                                                                  
float2 NfruMove(float2 p, float2 v, float k) { return NfruAngular() ? NfruFromAngle(NfruToAngle(p) + v * k) : p + v * k; }
                                                                                                              
float2 NfruSpace(float2 p) { return NfruAngular() ? NfruToAngle(p) : p; }
float2 NfruMoveFrom(float2 space, float2 v, float k) { return NfruAngular() ? NfruFromAngle(space + v * k) : space + v * k; }
#endif
