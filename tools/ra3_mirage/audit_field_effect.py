"""Read Uprising FXLightning effect states/preshader constants on a hidden D3D9 device.

Requires Windows and a local Microsoft x64 d3dx9_43.dll. Does not install a DLL,
draw to the desktop, run the game, or change game assets. COM indices follow the
public ID3DXEffect / IDirect3DDevice9 interfaces, not private engine offsets.
"""
import argparse
import ctypes as c
import hashlib
import json
from pathlib import Path

from extract_uprising import Big

P, U, H, F = c.c_void_p, c.c_uint, c.c_long, c.c_float


class PresentParameters(c.Structure):
    _fields_ = [(name, kind) for name, kind in [
        ('width', U), ('height', U), ('format', U), ('count', U), ('multi', U),
        ('quality', U), ('swap', U), ('window', P), ('windowed', c.c_int),
        ('auto_depth', c.c_int), ('depth', U), ('flags', U), ('hz', U), ('interval', U)]]


def call(obj, index, result, types, *args):
    table = c.cast(obj, c.POINTER(c.POINTER(P))).contents
    return c.WINFUNCTYPE(result, P, *types)(table[index])(obj, *args)


def checked(hr):
    if hr < 0:
        raise RuntimeError(f'Direct3D HRESULT {hr & 0xffffffff:08x}')


def audit(game, dll, material, output):
    archive = Big(game / 'Data/Shaders.big')
    name = next(n for n in archive.entries if n.lower().endswith('\\fxlightning.fxo'))
    raw = archive.read(name)
    constants = json.loads(material.read_text())['material']['constants']
    user = c.WinDLL('user32')
    user.CreateWindowExW.restype = P
    user.CreateWindowExW.argtypes = [U, c.c_wchar_p, c.c_wchar_p, U,
                                    c.c_int, c.c_int, c.c_int, c.c_int, P, P, P, P]
    user.DestroyWindow.argtypes = [P]
    hwnd = user.CreateWindowExW(0, 'STATIC', 'RA3 shader audit', 0, 0, 0, 8, 8, None, None, None, None)
    if not hwnd:
        raise c.WinError()
    objects = []
    try:
        d3d = c.WinDLL('d3d9')
        d3d.Direct3DCreate9.restype = P
        api = d3d.Direct3DCreate9(32)
        if not api:
            raise RuntimeError('Direct3DCreate9 failed')
        objects.append(api)
        device = P()
        pp = PresentParameters(8, 8, 0, 1, 0, 0, 1, hwnd, 1, 0, 0, 0, 0, 0)
        checked(call(api, 16, H, [U, U, P, U, c.POINTER(PresentParameters), c.POINTER(P)],
                     0, 1, hwnd, 0x20, c.byref(pp), c.byref(device)))
        objects.append(device)
        fx = c.WinDLL(str(dll.resolve()))
        fx.D3DXCreateEffect.argtypes = [P, P, U, P, P, U, P, c.POINTER(P), c.POINTER(P)]
        fx.D3DXCreateEffect.restype = H
        effect, error = P(), P()
        buffer = c.create_string_buffer(raw)
        hr = fx.D3DXCreateEffect(device, buffer, len(raw), None, None, 0, None, c.byref(effect), c.byref(error))
        if error:
            call(error, 2, U, [])
        checked(hr)
        objects.append(effect)

        def parameter(key):
            return call(effect, 9, P, [P, c.c_char_p], None, key.encode())

        for key, value in constants.items():
            handle = parameter(key)
            if not handle or isinstance(value, dict):
                continue
            if isinstance(value, bool):
                checked(call(effect, 22, H, [P, c.c_int], handle, int(value)))
            elif len(value) == 1:
                checked(call(effect, 30, H, [P, F], handle, value[0]))
            elif len(value) in (3, 4):
                checked(call(effect, 34, H, [P, c.POINTER(F)], handle, (F*4)(*(value+[0])[:4])))
        for key, value in [('OpacityOverride', 1.0), ('Time', 1.0)]:
            checked(call(effect, 30, H, [P, F], parameter(key), value))
        technique = call(effect, 12, P, [U], 0)
        checked(call(effect, 58, H, [P], technique))
        passes = U()
        checked(call(effect, 63, H, [c.POINTER(U), U], c.byref(passes), 0))
        checked(call(effect, 64, H, [U], 0))
        states = {}
        for key, index in [('SRCBLEND', 19), ('DESTBLEND', 20), ('ALPHABLENDENABLE', 27),
                           ('CULLMODE', 22), ('SRGBWRITEENABLE', 194)]:
            value = U()
            checked(call(device, 58, H, [U, c.POINTER(U)], index, c.byref(value)))
            states[key] = value.value
        vs = (F*104)()
        checked(call(device, 95, H, [U, c.POINTER(F), U], 0, vs, 26))
        checked(call(effect, 66, H, []))
        checked(call(effect, 67, H, []))
        result = dict(source=str(game/'Data/Shaders.big'), entry=name,
                      shader_sha256=hashlib.sha256(raw).hexdigest(), material=str(material),
                      material_sha256=hashlib.sha256(material.read_bytes()).hexdigest(),
                      states=states, vertex_constants={str(i): list(vs[i*4:i*4+4]) for i in range(26)},
                      limit='States and preshader constants only; no claim about RA3 CPU geometry or final frame parity')
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
        print(json.dumps(states))
    finally:
        for obj in reversed(objects):
            call(obj, 2, U, [])
        user.DestroyWindow(hwnd)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['game', 'dll', 'material', 'output']:
        parser.add_argument('--'+name, type=Path, required=True)
    args = parser.parse_args()
    audit(args.game, args.dll, args.material, args.output)
