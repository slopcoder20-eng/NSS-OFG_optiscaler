import os, sys, torch
import numpy as np

def main():
    cache_path = "/mnt/e/nss_VK/NSS/mlof2/cache_oft_samples.pt"
    out_dir = "/mnt/e/nss_VK/NSS/mlof2_engine/io_oft_sample"
    os.makedirs(out_dir, exist_ok=True)

    data = torch.load(cache_path, map_location="cpu")
    sample0 = data[0]
    name, t_val, ca, cb, of_ab, of_ba = sample0
    print(f"Dumping sample {name} (t={float(t_val):.2f})...")

                                                                                                           
    ca_pad = torch.cat([ca, torch.ones(1, 1, 1088, 1920, dtype=ca.dtype)], dim=1)
    cb_pad = torch.cat([cb, torch.ones(1, 1, 1088, 1920, dtype=cb.dtype)], dim=1)

    ca_nhwc = ca_pad.squeeze(0).permute(1, 2, 0).contiguous().numpy().astype(np.float32)
    cb_nhwc = cb_pad.squeeze(0).permute(1, 2, 0).contiguous().numpy().astype(np.float32)

                                                          
    of_ab_nhwc = of_ab.squeeze(0).permute(1, 2, 0).contiguous().numpy().astype(np.float32)
    of_ba_nhwc = of_ba.squeeze(0).permute(1, 2, 0).contiguous().numpy().astype(np.float32)

                     
    ca_nhwc.tofile(os.path.join(out_dir, "color_a.f32"))
    cb_nhwc.tofile(os.path.join(out_dir, "color_b.f32"))
    of_ab_nhwc.tofile(os.path.join(out_dir, "of_ab.f32"))
    of_ba_nhwc.tofile(os.path.join(out_dir, "of_ba.f32"))

                 
    fc = np.zeros(72, dtype=np.float32)
    fc[0] = float(t_val)
    fc.tofile(os.path.join(out_dir, "fc.f32"))

    print(f"Dumped to {out_dir}:")
    print(f"  color_a.f32: {ca_nhwc.shape} ({ca_nhwc.nbytes} bytes)")
    print(f"  color_b.f32: {cb_nhwc.shape} ({cb_nhwc.nbytes} bytes)")
    print(f"  of_ab.f32:   {of_ab_nhwc.shape} ({of_ab_nhwc.nbytes} bytes)")
    print(f"  of_ba.f32:   {of_ba_nhwc.shape} ({of_ba_nhwc.nbytes} bytes)")
    print(f"  fc.f32:      {fc.shape} ({fc.nbytes} bytes)")

if __name__ == "__main__":
    main()

