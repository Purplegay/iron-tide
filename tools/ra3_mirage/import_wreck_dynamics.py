"""Extract official collapse randomness; leave existing COL geometry untouched."""
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
from import_expansion import poid

ROOT = Path(__file__).resolve().parents[2]
EA = ROOT / 'refs/ea-modding-support/Uprising'
NS = {'s': 'uri:ea.com:eala:asset'}
TARGETS = {
    'mirage': ('Allied/Props/AlliedAntiVehicleVehicleTech3_Collapse.xml', 'mirage/native'),
    'future': ('EP1/Allied/Props/AlliedFutureTank_Collapse.xml', 'expansion/future'),
    'harbinger': ('EP1/Allied/Props/AlliedGunshipAircraft_Collapse.xml', 'expansion/harbinger'),
}


def main():
    sources, profiles = {}, {}

    def read(path):
        sources[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
        return ET.parse(path).getroot()

    read(EA / 'Schemas/Modules/DynamicsDraw.xsd')
    read(EA / 'Schemas/Includes/Dynamics.xsd')
    for key, (relative, geometry) in TARGETS.items():
        obj = read(EA / 'Xml' / relative).find('s:GameObject', NS)
        draw = obj.find('s:Draws/s:DynamicsDraw', NS)
        life = obj.find('s:Behaviors/s:LifetimeUpdate', NS)
        bodies = {(b.get('BoneName').upper() if key == 'mirage' else poid(b.get('BoneName')).upper()): {
            'bone': b.get('BoneName'),
            'mass': float(b.get('Mass')), 'spinniness': float(b.get('Spinniness')),
            'contact_tag': b.get('ContactTag'),
        } for b in draw.findall('s:BoneVolumes/s:BoneVolume', NS)}
        pieces = json.loads((ROOT / 'iron_tide/assets/ra3' / geometry / 'wreck.json').read_text())['pieces']
        assert set(bodies) == {p['name'].upper() for p in pieces}, key
        assert all(bodies[p['name'].upper()]['mass'] == p['mass'] for p in pieces), key
        profiles[key] = {
            'explodiness': float(draw.get('Explodiness')),
            'fling_perturbation': float(draw.get('FlingPerturbation')),
            'collision': draw.get('Collision'),
            'min_lifetime': float(life.get('MinLifetime').removesuffix('s')),
            'max_lifetime': float(life.get('MaxLifetime').removesuffix('s')),
            'bodies': bodies,
        }
        if key == 'mirage':
            sdk = read(ROOT / 'refs/ra3-sdk/installed/SAGEXML' / relative)
            sdk_draw = sdk.find('s:GameObject/s:Draws/s:DynamicsDraw', NS)
            assert sdk_draw.attrib == draw.attrib
            assert [b.attrib for b in sdk_draw.findall('s:BoneVolumes/s:BoneVolume', NS)] == [b.attrib for b in draw.findall('s:BoneVolumes/s:BoneVolume', NS)]
    out = ROOT / 'iron_tide/assets/ra3/wreck_dynamics.json'
    out.write_text(json.dumps({'profiles': profiles, 'sources': sources,
        'boundary': 'Official fields; motion scaling, gravity and ground settling are Godot cosmetic adaptations, not SAGE rigid-body parity.'}, indent=2) + '\n', encoding='utf-8')
    print('Imported collapse dynamics:', {k: len(v['bodies']) for k, v in profiles.items()})


if __name__ == '__main__':
    main()
