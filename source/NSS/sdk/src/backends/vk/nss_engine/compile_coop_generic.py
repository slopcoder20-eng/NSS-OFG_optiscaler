"""Build only the portable INT8 kernels, preserving all existing optimized SPIR-V."""
from pathlib import Path
import argparse
import shutil
import struct
import subprocess

root = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--compiler', default=shutil.which('glslangValidator') or str(root.parents[3] / 'tools/binary_store/glslangValidator.exe'))
args = parser.parse_args()
lines = ['// Generated from shaders_src/conv_coop_generic.comp; do not edit.', '#pragma once', '#include <stdint.h>', '#include <stddef.h>']
for kind in ('nss', 'nfru'):
    spv = root / 'shaders_src' / f'conv_coop_generic_{kind}.spv'
    command = [args.compiler, '-V', '--target-env', 'vulkan1.2']
    if kind == 'nfru': command += ['-DNFRU=1']
    subprocess.run(command + [str(root/'shaders_src/conv_coop_generic.comp'), '-o', str(spv)], check=True)
    data = spv.read_bytes()
    words = struct.unpack('<' + 'I' * (len(data)//4), data)
    name = f'g_spv_conv_coop_generic_{kind}'
    lines += [f'static const uint32_t {name}[] = {{']
    lines += [','.join(f'0x{x:08x}' for x in words[i:i+8])+',' for i in range(0,len(words),8)]
    lines += ['};', f'static const size_t {name}_size = sizeof({name});']
(root/'coopmat_generic_spv.h').write_text('\n'.join(lines)+'\n', encoding='utf-8')
