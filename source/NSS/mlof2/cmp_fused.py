import numpy as np, math

c_old = np.fromfile('E:/nss_VK/NSS/mlof2_engine/io_oft_sample/op_072.bin', dtype=np.float16).astype(np.float32)
c_new = np.fromfile('E:/nss_VK/NSS/mlof2_engine/io_oft_sample/op_069.bin', dtype=np.float16).astype(np.float32)
mse = np.mean((c_old - c_new)**2)
psnr = -10 * math.log10(max(mse, 1e-10))
print(f"PSNR before vs after fusion: {psnr:.2f} dB")
print(f"Max absolute diff: {np.max(np.abs(c_old - c_new)):.6f}")
print(f"Mean absolute diff: {np.mean(np.abs(c_old - c_new)):.6f}")

