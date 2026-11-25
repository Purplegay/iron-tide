"""Read-only, SHA-pinned Uprising laser CPU oracle (Windows x86).

Runs only the call-free billboard arithmetic block in a separate 32-bit process.
No game process is opened or modified. Original bytes stay in the ignored report
directory; only constant-address relocations and a calling wrapper are added.
"""
import argparse
import base64
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import subprocess

SOURCE_SHA = 'b1da83efd229570bab9de3a14e48b2d1e6128e302bd52384858fa8a413ae330b'
START, END = 0x5fed9b, 0x5ff428


def pe_read(data, va, size):
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    count, optional = struct.unpack_from('<H', data, pe + 6)[0], struct.unpack_from('<H', data, pe + 20)[0]
    base = struct.unpack_from('<I', data, pe + 24 + 28)[0]
    for i in range(count):
        section = pe + 24 + optional + 40 * i
        _, rva, length, offset = struct.unpack_from('<4I', data, section + 8)
        if rva <= va - base and va - base + size <= rva + length:
            start = offset + va - base - rva
            return data[start:start + size]
    raise ValueError('Unmapped PE address')


def norm(v):
    length = math.sqrt(sum(x*x for x in v))
    return [x/length for x in v] if length else [0., 0., 0.]


def expected(case):
    a, b, camera = case['start'], case['end'], case['camera']
    delta = [y-x for x, y in zip(a, b)]
    direction = norm(delta) if sum(x*x for x in delta) > 1e-4 else delta
    view = norm([c-(x+y)*.5 for x, y, c in zip(a, b, camera)])
    side = [direction[1]*view[2]-direction[2]*view[1],
            direction[2]*view[0]-direction[0]*view[2],
            direction[0]*view[1]-direction[1]*view[0]]
    offset = [x*case['width']*.5 for x in side]
    age = case['now']-case['created']
    clamp = lambda x: max(0., min(1., x))
    opacity = clamp(age/case['fade_in']) if case['fade_in'] > 0 else 1.
    if case['fade_out'] > 0 and case['expires'] != -1:
        opacity *= clamp((case['expires']-case['now'])/case['fade_out'])
    # Native order: start+side, start-side, end+side, end-side.
    vertices = []
    for p, sign, u, v in [(a, 1, 0, 1), (a, -1, 1, 1), (b, 1, 0, 0), (b, -1, 1, 0)]:
        vertices.append({'position': [x+sign*y for x, y in zip(p, offset)],
                         'uv0': [u+.2*age, v+.3*age],
                         'uv1': [u-.2*age, v-.3*age], 'opacity': opacity})
    return vertices


CS = r'''
using System;
using System.Runtime.InteropServices;
public static class LaserOracle {
 [DllImport("kernel32")] static extern IntPtr VirtualAlloc(IntPtr a, UIntPtr n, uint t, uint p);
 [DllImport("kernel32")] static extern bool VirtualFree(IntPtr a, UIntPtr n, uint t);
 [DllImport("kernel32")] static extern bool VirtualProtect(IntPtr a, UIntPtr n, uint p, out uint old);
 [DllImport("kernel32")] static extern bool FlushInstructionCache(IntPtr p, IntPtr a, UIntPtr n);
 [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void Draw(IntPtr laser, IntPtr camera, IntPtr vertices, float now);
 public static float[] Run(byte[] code, int[] offsets, float[] constants, float[] laser, float[] camera, float now) {
  if (IntPtr.Size != 4) throw new Exception("Requires x86 process");
  IntPtr c=Marshal.AllocHGlobal(constants.Length*4), l=Marshal.AllocHGlobal(0x80), cam=Marshal.AllocHGlobal(12), v=Marshal.AllocHGlobal(0x110);
  IntPtr executable=IntPtr.Zero;
  try {
   Marshal.Copy(constants,0,c,constants.Length);
   for(int i=0;i<offsets.Length;i++) Array.Copy(BitConverter.GetBytes(c.ToInt32()+i*4),0,code,offsets[i],4);
   Marshal.Copy(laser,0,l,laser.Length); Marshal.Copy(camera,0,cam,3);
   executable=VirtualAlloc(IntPtr.Zero,(UIntPtr)code.Length,0x3000,0x04);
   if(executable==IntPtr.Zero) throw new Exception("VirtualAlloc failed");
   Marshal.Copy(code,0,executable,code.Length); uint old;
   if(!VirtualProtect(executable,(UIntPtr)code.Length,0x20,out old)) throw new Exception("VirtualProtect failed");
   if(!FlushInstructionCache(new IntPtr(-1),executable,(UIntPtr)code.Length)) throw new Exception("FlushInstructionCache failed");
   ((Draw)Marshal.GetDelegateForFunctionPointer(executable,typeof(Draw)))(l,cam,v,now);
   float[] result=new float[68]; Marshal.Copy(v,result,0,68); return result;
  } finally { if(executable!=IntPtr.Zero) VirtualFree(executable,UIntPtr.Zero,0x8000); Marshal.FreeHGlobal(c); Marshal.FreeHGlobal(l); Marshal.FreeHGlobal(cam); Marshal.FreeHGlobal(v); }
 }
}
'''


def audit(game, output, fixture=None):
    data = game.read_bytes()
    if hashlib.sha256(data).hexdigest() != SOURCE_SHA:
        raise ValueError('Unknown executable: refuse to execute unverified bytes')
    raw = pe_read(data, START, END-START)
    # Preserve nonvolatile registers; build the original stack/register inputs.
    wrapper = bytes.fromhex('53 55 56 57 81ec10010000 8bb42424010000 8b8c242c010000 83c168 '
                            '8b842430010000 89442454 8b842428010000 '
                            '8b10 899424b0000000 8b5004 899424b4000000 8b5008 899424b8000000 '
                            'b80000003f 660f6ee8 d9e8')
    code = wrapper + raw + bytes.fromhex('ddd8 81c410010000 5f5e5d5b c3')
    offsets, constants = [], []
    for address in [0xbf7e5c, 0xc00b48, 0xc1f560, 0xbf82a8]:
        needle = struct.pack('<I', address)
        position = 0
        while (position := raw.find(needle, position)) >= 0:
            offsets.append(len(wrapper)+position)
            constants.append(struct.unpack('<f', pe_read(data, address, 4))[0])
            position += 4
    assert len(offsets) == 5
    cases = []
    for width in [25., 5.]:
        for age in [0., .2, .75, 1.49]:
            for end in [[120., 0., 0.], [0., 120., 0.], [60., 80., 25.]]:
                cases.append(dict(start=[0., 0., 10.], end=end, camera=[0., -866025.4, 500000.],
                                  width=width, now=age, created=0., expires=1.5, fade_in=0., fade_out=0.))
    for age in [-.1, 0., .1, .2, .8, 1., 1.2]:
        cases.append(dict(cases[0], now=age, expires=1., fade_in=.2, fade_out=.4))
    cases += [dict(cases[0], now=.9, expires=-1., fade_out=.5),
              dict(cases[0], now=5.2, created=5., expires=6.5),
              dict(cases[0], end=[0., 0., 10.]),
              dict(cases[0], end=[.001, 0., 10.])]
    for case in cases:
        laser = [0.]*32
        laser[1:4], laser[4:7] = case['start'], case['end']
        laser[7:16] = [case['width'], 1., 1., 1., 1., .2, .3, -.2, -.3]
        # These fields are integers in the original structure.
        laser[16] = laser[18] = struct.unpack('<f', struct.pack('<I', 1))[0]
        laser[20:24] = [case['created'], case['expires'], case['fade_in'], case['fade_out']]
        case['laser'] = laser
    output.mkdir(parents=True, exist_ok=True)
    (output/'oracle.cs').write_text(CS, encoding='utf-8')
    (output/'input.json').write_text(json.dumps(dict(code=base64.b64encode(code).decode(), offsets=offsets, constants=constants, cases=cases)), encoding='utf-8')
    script = r'''
$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'oracle.cs')
$inputData=Get-Content -Raw (Join-Path $PSScriptRoot 'input.json') | ConvertFrom-Json
$results=@(foreach($c in $inputData.cases) {
 $values=[LaserOracle]::Run([Convert]::FromBase64String($inputData.code),[int[]]$inputData.offsets,[float[]]$inputData.constants,[float[]]$c.laser,[float[]]$c.camera,[float]$c.now)
 ,@($values)
})
ConvertTo-Json -Depth 10 -InputObject $results | Set-Content -Encoding UTF8 (Join-Path $PSScriptRoot 'native.json')
'''
    (output/'run.ps1').write_text(script, encoding='utf-8')
    shell = Path(os.environ['WINDIR'])/'SysWOW64/WindowsPowerShell/v1.0/powershell.exe'
    subprocess.run([str(shell), '-NoProfile', '-File', str(output/'run.ps1')], check=True, timeout=40)
    native = json.loads((output/'native.json').read_text(encoding='utf-8-sig'))
    checks, maximum = 0, 0.
    samples = []
    for case, vertices in zip(cases, native, strict=True):
        wanted = expected(case)
        result = []
        for i, expected_vertex in enumerate(wanted):
            actual = {'position': vertices[i*17:i*17+3], 'uv0': vertices[i*17+6:i*17+8],
                      'uv1': vertices[i*17+8:i*17+10], 'opacity': vertices[i*17+16]}
            for key, value in actual.items():
                av = value if isinstance(value, list) else [value]
                ev = expected_vertex[key] if isinstance(value, list) else [expected_vertex[key]]
                for x, y in zip(av, ev):
                    error = abs(x-y)
                    maximum = max(maximum, error)
                    assert error < 0.0001, (case, i, key, x, y)
                    checks += 1
            result.append(actual)
        samples.append(dict(input={k:v for k,v in case.items() if k != 'laser'}, vertices=result))
    report = dict(source=str(game), sha256=SOURCE_SHA, instruction_range=[hex(START), hex(END)],
                  instruction_sha256=hashlib.sha256(raw).hexdigest(), cases=len(cases), checks=checks,
                  max_absolute_error=maximum, passed=True, samples=samples,
                  boundary='Original CPU arithmetic only; fixture inputs, no game update loop, camera or GPU execution.')
    (output/'audit.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    if fixture is not None:
        selected = []
        for index in [0, 1, 2, 12, 13, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34]:
            sample = samples[index]
            selected.append(dict(sample['input'], half_width=[(a-b)*.5 for a,b in zip(sample['vertices'][0]['position'],sample['vertices'][1]['position'])], opacity=sample['vertices'][0]['opacity']))
        fixture.write_text(json.dumps(dict(source_sha256=SOURCE_SHA, instruction_sha256=report['instruction_sha256'], cases=selected),indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k != 'samples'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--fixture', type=Path, help='Export selected original-instruction outputs as a portable regression baseline')
    args = parser.parse_args()
    audit(args.game, args.output.resolve(), args.fixture)
