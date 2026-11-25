"""Read-only, SHA-pinned Uprising DamageSphereUpdate static evidence.

Does not execute the engine or claim to reproduce its whole object/weapon scheduler.
Instruction ranges can be independently disassembled with any x86 disassembler.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from xml.etree import ElementTree as ET

SOURCE_SHA = 'b1da83efd229570bab9de3a14e48b2d1e6128e302bd52384858fa8a413ae330b'
ROOT = Path(__file__).resolve().parents[2]
NS = {'s': 'uri:ea.com:eala:asset'}


def audit(game, output):
    data = game.read_bytes()
    assert hashlib.sha256(data).hexdigest() == SOURCE_SHA, 'Wrong Uprising executable'
    pe = struct.unpack_from('<I', data, 0x3c)[0]
    count, optional = struct.unpack_from('<H', data, pe+6)[0], struct.unpack_from('<H', data, pe+20)[0]
    base = struct.unpack_from('<I', data, pe+52)[0]
    sections = [struct.unpack_from('<4I', data, pe+24+optional+i*40+8) for i in range(count)]

    def read(va, length):
        for _, rva, size, offset in sections:
            if rva <= va-base and va-base+length <= rva+size:
                start = offset+va-base-rva
                return data[start:start+length]
        raise ValueError(hex(va))

    # Constructor binds this class's vtables; virtual getName points to the
    # literal DamageSphereUpdate. This distinguishes it from ShieldSphereUpdate.
    assert read(0x7a827d, 6) == bytes.fromhex('c70630f1c500')
    assert struct.unpack('<I', read(0xc5f138, 4))[0] == 0x7a83c0
    assert read(0x7a83c0, 6) == bytes.fromhex('b8f83ec300c3')
    assert read(0xc33ef8, 19) == b'DamageSphereUpdate\0'
    assert struct.unpack('<I', read(0xc5efd8, 4))[0] == 0x7e2b70
    assert struct.unpack('<I', read(0xce6f70+3*4, 4))[0] == 0xb19240
    hz = struct.unpack('<I', read(0xccce90, 4))[0]
    assert hz == 15
    assert read(0xbc5596, 6) == bytes.fromhex('d91db88bcf00')
    ranges = {
        'constructor_unpack_and_expansion_step': (0x7a8260, 0x7a83b4),
        'activate_radius_min_and_set_status': (0x778b60, 0x778c20),
        'query_sphere_then_fire_per_target': (0x7e2b70, 0x7e2d3d),
        'increment_clamp_radius_and_finished_flag': (0x7100e0, 0x710106),
        'finish_sleep_forever_or_return_one_frame': (0x7c55b0, 0x7c5627),
        'mode3_xyz_bounding_sphere_distance': (0xb19240, 0xb192e4),
        'initialize_native_logic_time_factor': (0xbc5580, 0xbc559e),
    }
    source = ROOT/'refs/ea-modding-support/Uprising/Xml/EP1/Allied/Props/AlliedFutureTankNeutronScramblerNode.xml'
    root = ET.parse(source).getroot()
    sphere = root.find('.//s:DamageSphereUpdate', NS).attrib
    radius, maximum, step = float(sphere['RadiusMin']), float(sphere['RadiusMax']), float(sphere['ExpansionPerSecond'])/hz
    radii = []
    # Translation of query-before-increment, not a native-execution oracle.
    while radius < maximum:
        radii.append(radius)
        radius = min(maximum, radius+step)
    report = {
        'source': str(game), 'sha256': SOURCE_SHA,
        'xml': str(source), 'xml_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'instruction_ranges': {name: {'start': hex(a), 'end_exclusive': hex(b), 'sha256': hashlib.sha256(read(a,b-a)).hexdigest()} for name,(a,b) in ranges.items()},
        'static_binding_checks': 8, 'simulation_hz': hz,
        'unpack_frame': int(float(sphere['UnpackTime'].rstrip('s'))*hz),
        'expansion_query_radii': radii,
        'boundary': 'Static retail disassembly and XML. Radius timeline is a translation, not executed native code. Full scheduler and SAGE geometry remain outside this check.',
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'static_binding_checks': 8, 'simulation_hz': hz, 'expansion_ticks': len(radii), 'output': str(output)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    audit(args.game, args.output)
