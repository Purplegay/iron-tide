"""SHA-pinned, read-only Uprising particle random-range evidence.

Static instruction assertions, not an executed original-engine visual oracle.
No disassembler dependency and no changes to the installed game.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE_SHA = 'b1da83efd229570bab9de3a14e48b2d1e6128e302bd52384858fa8a413ae330b'


def audit(game, output):
    data = game.read_bytes()
    assert hashlib.sha256(data).hexdigest() == SOURCE_SHA, 'Wrong Uprising executable'
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    count = struct.unpack_from('<H', data, pe+6)[0]
    optional = struct.unpack_from('<H', data, pe+20)[0]
    base = struct.unpack_from('<I', data, pe+52)[0]
    sections = [struct.unpack_from('<4I', data, pe+24+optional+i*40+8) for i in range(count)]

    def read(va, length):
        for _, rva, size, offset in sections:
            if rva <= va-base and va-base+length <= rva+size:
                start = offset+va-base-rva
                return data[start:start+length]
        raise ValueError(hex(va))

    # RenderObjectParticleUpdateModule constructor samples its XML random variables.
    assert read(0x6e974e, 5) == bytes.fromhex('e8ed9ef4ff')
    assert 0x6e974e+5+struct.unpack('<i', read(0x6e974f, 4))[0] == 0x633640
    assert read(0x6e9730, 6) == bytes.fromhex('c7067806c300')
    assert struct.unpack('<I', read(0xc30688, 4))[0] == 0x6dd9e0
    # xmm2=Low, xmm1=High, xmm0=High-Low; compare zero against the difference.
    assert read(0x633670, 17) == bytes.fromhex('f30f105104f30f1049080f28c1f30f5cc2')
    assert read(0x633687, 25) == bytes.fromhex('0f57d20f2fd0f30f110424720cf30f110c24d9042483c40cc3')
    # JB goes to RNG only when zero < High-Low. Otherwise load High and return.
    ranges = {
        'client_random_variable': (0x633640, 0x6336cd),
        'drawable_particle_constructor': (0x6e9720, 0x6e987b),
        'size_add_rate_then_damp_rate': (0x6dd9e0, 0x6ddaa0),
        'drawable_transform_scale': (0x6e956e, 0x6e9657),
    }
    source = ROOT/'iron_tide/assets/ra3/expansion/fx/gunship_effects.json'
    effects = json.loads(source.read_text(encoding='utf-8'))

    def child(node, path):
        for tag in path.split('/'):
            node = next(c for c in node['children'] if c['tag'] == tag)
        return node

    cases = []
    for name in ('FXAlliedGunshipProtonSW', 'FXAlliedGunshipVetSW'):
        for axis in ('y', 'z'):
            rate = child(effects['particles'][name], 'Update/RenderObject/SizeRate/'+axis)['attrs']
            damping = child(effects['particles'][name], 'Update/RenderObject/SizeDamping/'+axis)['attrs']
            assert (float(rate['Low']), float(rate['High'])) == (0.75, 0.1)
            assert float(damping['Low']) == float(damping['High']) == 0.95
            cases.append({'particle': name, 'axis': axis, 'low': .75, 'high': .1,
                          'native_result': .1, 'radial_scale_limit': .1/(1-.95)})
    report = {
        'source': str(game), 'sha256': SOURCE_SHA,
        'particle_source': str(source), 'particle_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'instruction_ranges': {name: {'start': hex(a), 'end_exclusive': hex(b),
            'sha256': hashlib.sha256(read(a, b-a)).hexdigest()} for name, (a, b) in ranges.items()},
        'cases': cases,
        'rule': 'High <= Low returns High; positive interval uses Low + (High-Low) * random.',
        'boundary': 'Static retail CPU evidence. Particle wall-clock scheduling, HDR, depth and RNG stream equivalence are not proved.',
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'cases': len(cases), 'output': str(output)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    audit(args.game, args.output)
