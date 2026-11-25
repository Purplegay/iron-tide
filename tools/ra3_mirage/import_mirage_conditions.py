"""Import Mirage model conditions from official SDK; media from installed Uprising."""
import hashlib
import json
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SDK = ROOT / 'refs/ra3-sdk/installed'
EA = ROOT / 'refs/ea-modding-support/Uprising'
OUT = ROOT / 'iron_tide/assets/ra3/mirage/damage'
NS = {'s': 'uri:ea.com:eala:asset'}

def tree(e):
    result = {'tag': e.tag.split('}')[-1], 'attrs': e.attrib,
              'children': [tree(c) for c in e]}
    if e.text and e.text.strip():
        result['text'] = e.text.strip()
    return result

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sources = {}
    def record(p):
        sources[p.relative_to(ROOT).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
    def read(p):
        record(p)
        return ET.parse(p).getroot()
    unit_path = 'Allied/Units/AlliedAntiVehicleVehicleTech3.xml'
    unit = read(SDK / 'SAGEXML' / unit_path).find('s:GameObject', NS)
    uprising = read(EA / 'Xml' / unit_path).find('s:GameObject', NS)
    states = [tree(e) for e in unit.findall('s:Draws/*', NS)]
    other = {e.get('id', e.tag.split('}')[-1]): tree(e) for e in uprising.findall('s:Draws/*', NS)}
    differences = [e['attrs'].get('id', e['tag']) for e in states if e != other.get(e['attrs'].get('id', e['tag']))]
    assert differences == ['ModuleTag_ShieldDraw', 'ModuleTag_LaserDraw_Vet'], differences
    # Base RA3/Uprising differ for EMP/paralysis field states and heroic beam
    # emissive RGB, not damage texture/particles. Keep these versions distinct.
    thresholds = {}
    for e in read(SDK / 'Schemas/xsd/Modules/ActiveBody.xsd').iter():
        if e.get('name') in ['MaxHealthDamagedPercentage', 'MaxHealthReallyDamagedPercentage']:
            thresholds[e.get('name')] = float(e.get('default')) / 100
    particles = {}
    for name in ['VehicleDamageSmoke', 'VehicleDamageFire', 'VehicleDamageFire02']:
        particles[name] = tree(read(SDK / 'SAGEXML/FXParticleSystems' / (name + '.xml')).find('s:FXParticleSystemTemplate', NS))
    fx_path = ROOT / 'refs/ra3-mirage/uprising/converted/hierarchies/W3DHierarchy_AUANTIVEHICLEVEHICLETECH3_FX.json'
    record(fx_path)
    bones = json.loads(fx_path.read_text())['bones']
    names_path = ROOT / 'refs/ra3-community/art/Allied Art Pack/Vehicles/Mirage Tank/AUANTIVEHICLEVEHICLETECH3_FX_HRC.w3x'
    pivots = read(names_path).find('s:W3DHierarchy', NS).findall('s:Pivot', NS)
    index = next(i for i, p in enumerate(pivots) if p.get('Name') == 'FX_BONE01')
    bone = bones[index]
    assert bone['parent'] == 0 and bones[0]['parent'] == -1
    declared = pivots[index].find('s:Translation', NS)
    assert max(abs(float(declared.get(axis)) - value) for axis, value in zip('XYZ', bone['translation'])) < 0.00001
    x, y, z = bone['translation']
    textures = {}
    for name, group in [('AUAntiVehicleVehicleTech3_D', 'uprising'), ('FXFireScroll3', 'uprising'),
                        ('FXFire02', 'damage-state'), ('FXFireGrid', 'damage-state')]:
        p = ROOT / f'refs/ra3-mirage/{group}/converted/textures/Texture_{name}.png'
        record(p)
        shutil.copyfile(p, OUT / (name + '.png'))
        textures[name] = hashlib.sha256((OUT / (name + '.png')).read_bytes()).hexdigest()
    locomotors = read(SDK / 'SAGEXML/GlobalData/Locomotor.xml')
    locomotor = next(e for e in locomotors if e.get('id') == 'AlliedAntiVehicleVehicleTech3Locomotor')
    data = {'thresholds': thresholds, 'draws': states, 'particles': particles,
            'damage_emitter': {'bone': 'FX_BONE01', 'position': [x, z, -y]},
            'damaged_speed_factor': float(locomotor.get('MaxSpeedDamaged').strip('%')) / 100,
            'sources': sources, 'textures': textures, 'uprising_draw_differences': differences,
            'adapter': 'Godot 2D particles at native 30 FPS; no SAGE scene-depth distortion or swirly solver'}
    (OUT / 'conditions.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Mirage:', len(states), 'SDK draw modules, 3 damage particle templates, 4 textures; version differences:', differences)

if __name__ == '__main__':
    main()
