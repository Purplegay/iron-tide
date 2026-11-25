"""Read-only Windows audit of installed Uprising Laser.fxo via D3DDisassemble."""
import argparse
import ctypes
import hashlib
import json
import struct
from pathlib import Path

from extract_uprising import Big


def audit(game: Path, output: Path):
    archive = Big(game / 'Data/Shaders.big')
    name = next(n for n in archive.entries if n.lower().endswith('\\laser.fxo'))
    data = archive.read(name)
    compiler = ctypes.WinDLL('d3dcompiler_47.dll')
    disassemble = compiler.D3DDisassemble
    disassemble.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_uint,
                           ctypes.c_char_p, ctypes.POINTER(ctypes.c_void_p)]
    disassemble.restype = ctypes.c_long
    output.mkdir(parents=True, exist_ok=True)
    shaders = []
    for offset in range(0, len(data) - 4, 4):
        version = struct.unpack_from('<I', data, offset)[0]
        if version not in (0xffff0200, 0xffff0300, 0xfffe0200, 0xfffe0300):
            continue
        cursor = offset + 4
        while cursor + 4 <= len(data):
            token = struct.unpack_from('<I', data, cursor)[0]
            opcode = token & 0xffff
            if opcode == 0xffff:
                break
            size = (token >> 16) & 0x7fff if opcode == 0xfffe else (token >> 24) & 15
            cursor += (1 + size) * 4
        else:
            continue
        raw = ctypes.create_string_buffer(data[offset:cursor + 4])
        blob = ctypes.c_void_p()
        if disassemble(raw, cursor + 4 - offset, 0, None, ctypes.byref(blob)) != 0:
            continue
        table = ctypes.cast(blob, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
        try:
            ptr = ctypes.WINFUNCTYPE(ctypes.c_void_p, ctypes.c_void_p)(table[3])(blob)
            size = ctypes.WINFUNCTYPE(ctypes.c_size_t, ctypes.c_void_p)(table[4])(blob)
            assembly = ctypes.string_at(ptr, size).decode().rstrip('\0')
        finally:
            ctypes.WINFUNCTYPE(ctypes.c_ulong, ctypes.c_void_p)(table[2])(blob)
        if '???' in assembly or not assembly.startswith('//'):
            continue
        (output / f'{offset}.asm').write_text(assembly, encoding='utf-8')
        shaders.append({'offset': offset, 'version': hex(version),
                        'texture_product': 'mul r1, r1, r2' in assembly,
                        'vertex_opacity': 'mul r1.w, r1.w, v0.x' in assembly})
    assert any(s['texture_product'] and s['vertex_opacity'] for s in shaders)
    result = {'source': str(game / 'Data/Shaders.big'), 'entry': name,
              'shader_sha256': hashlib.sha256(data).hexdigest(), 'shaders': shaders,
              'limit': 'Pixel/vertex arithmetic only; CPU geometry/opacity separately verified by audit_laser_cpu.py'}
    (output / 'audit.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    audit(args.game, args.output)
