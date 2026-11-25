"""Verify official projectile/heroic references and SHA-pinned retail acceleration evidence.

Read-only native inspection; the report is not a native-engine execution oracle.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
SHA = 'b1da83efd229570bab9de3a14e48b2d1e6128e302bd52384858fa8a413ae330b'
NS = {'s': 'uri:ea.com:eala:asset', 'xs': 'http://www.w3.org/2001/XMLSchema'}


def audit(game, output):
    data = game.read_bytes()
    assert hashlib.sha256(data).hexdigest() == SHA, 'Wrong native executable'
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

    # Bind constructor -> named class -> update vtable -> distance/acceleration routine.
    assert read(0x79ceae, 6).hex() == 'c706600dc500'
    assert struct.unpack('<I', read(0xc50d68, 4))[0] == 0x7560f0
    assert read(0x7560f0, 6).hex() == 'b81855c200c3'
    assert read(0xc25518, 25) == b'BezierProjectileBehavior\0'
    assert struct.unpack('<I', read(0xc50c04, 4))[0] == 0x819310
    assert read(0x81975b, 15).hex() == '8d4c243c8d6ef0518bcde866e2efff'
    assert read(0x7cdc20, 36).hex() == 'f30f1083f80000000f2ec59ff6c4447a0bd9467cd99ec8000000eb08f30f11aec8000000'
    assert read(0x717a21, 45).hex() == '8b51040f28c8f30f5889cc000000f30f1189cc000000f30f108af80000000f57f6f30f58c8f30f1189c8000000'
    assert struct.unpack('<I', read(0xccce90, 4))[0] == 15
    paths = [
        'Xml/EP1/Allied/Props/AlliedFutureTankNeutronWeaponProjectile.xml',
        'Xml/EP1/Allied/Props/AlliedFutureTankNeutronScramblerNode.xml',
        'Xml/EP1/Allied/Units/AlliedFutureTank.xml',
        'Xml/EP1/GlobalData/Weapon_EP1.xml',
        'Xml/BaseObjects/BaseProjectile.xml',
        'Schemas/Modules/BezierProjectile.xsd',
    ]
    root = ROOT/'refs/ea-modding-support/Uprising'
    objects = ET.parse(root/paths[0]).getroot().findall('s:GameObject', NS)
    result = []
    for obj in objects:
        movement = obj.find('.//s:BezierProjectile', NS).attrib
        assert movement['Acceleration'] == '5'
        assert [movement[x] for x in ('FirstHeightMin', 'FirstHeightMax', 'SecondHeightMin', 'SecondHeightMax')] == ['5', '5', '0', '0']
        assert movement['FirstPercentIndent'] == '33' and movement['SecondPercentIndent'] == '66'
        assert movement['CurveFlattenMinDist'] == '300' and movement['FlightPathAdjustDistPerSecond'] == '20'
        result.append({'id': obj.get('id'), 'model': obj.find('.//s:Model', NS).get('Name'), 'movement': movement})
    assert result[0]['model'] == 'FXFutureProjectile02'
    assert result[1]['model'] == 'FXFutureProjectile02_Vet'
    assert 'Flags' not in result[1]['movement']  # Replace does not retain the normal flags.
    schema = ET.parse(root/paths[-1]).getroot()
    assert schema.find(".//xs:attribute[@name='Flags']", NS).get('default') == 'PING_PONG_SIDEWAYS_DRIFT'
    unit = ET.parse(root/paths[2]).getroot()
    upgrade = unit.find(".//s:StatusBitsUpgrade[@StatusToSet='WEAPON_UPGRADED_02']", NS)
    assert upgrade is not None and 'Upgrade_Veterancy_HEROIC' in ''.join(upgrade.itertext())
    ranges = {'zero_speed_for_nonzero_acceleration': (0x7cdc20, 0x7cdc44),
              'distance_then_acceleration': (0x717a21, 0x717a4e),
              'distance_along_sampled_segments': (0x717a4e, 0x717ba9),
              'control_height_flattening': (0x7b32e2, 0x7b33d8)}
    report = {'native_sha256': SHA, 'native_binding_checks': 9, 'simulation_hz': 15,
              'objects': result, 'heroic_gate': 'Upgrade_Veterancy_HEROIC',
              'sources': {name: hashlib.sha256((root/name).read_bytes()).hexdigest() for name in paths},
              'ranges': {name: {'start': hex(a), 'end': hex(b), 'sha256': hashlib.sha256(read(a, b-a)).hexdigest()} for name, (a, b) in ranges.items()},
              'boundary': 'Static disassembly plus official XML. Godot uses 32-segment arc length, projected muzzle and flat-terrain/contact adapters; no claim of identical SAGE collision or scheduler.'}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'native_binding_checks': 9, 'variants': len(result), 'heroic_gate': report['heroic_gate'], 'output': str(output)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    audit(args.game, args.output)
