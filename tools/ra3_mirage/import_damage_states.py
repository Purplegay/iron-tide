"""Import scoped retail damage textures and literal EA particle XML, with hashes."""
import hashlib
import json
import shutil
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EA = ROOT / 'refs/ea-modding-support/Uprising'
OUT = ROOT / 'iron_tide/assets/ra3/expansion/damage'

def node(e):
    return {'tag': e.tag.split('}')[-1], 'attrs': e.attrib,
            'children': [node(c) for c in e]}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sources = {}
    def record(p):
        sources[p.relative_to(ROOT).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
    particles = {}
    for name in ['AlliedVehicleDamageSmoke', 'AlliedVehicleDamageFire', 'AlliedVehicleDamageFireLight']:
        p = EA / 'Xml/FXParticleSystems' / (name + '.xml')
        record(p)
        particles[name] = node(next(e for e in ET.parse(p).getroot() if e.tag.endswith('FXParticleSystemTemplate')))
    for name in ['AUFutureTank_D', 'AUGunship_D', 'FXFactorySteam01', 'FXFireScroll3', 'FXDisotrtionFractal01']:
        group = 'uprising' if name.startswith('AU') else 'damage-state'
        p = ROOT / f'refs/ra3-expansion/{group}/converted/textures/Texture_{name}.png'
        record(p)
        shutil.copyfile(p, OUT / (name + '.png'))
    p = EA / 'Schemas/Modules/ActiveBody.xsd'
    record(p)
    thresholds = {}
    for e in ET.parse(p).iter():
        if e.attrib.get('name') in ['MaxHealthDamagedPercentage', 'MaxHealthReallyDamagedPercentage']:
            thresholds[e.attrib['name']] = float(e.attrib['default']) / 100
    for p in [EA/'Shaders/GpuParticleDistort.fx', EA/'Shaders/CommonParticle.fxh']:
        record(p)
    record(EA/'Schemas/AssetTypeLocomotorTemplate.xsd')
    for name in ['AlliedFutureTank', 'AlliedGunshipAircraft']:
        record(EA/'Xml/EP1/Allied/Units'/f'{name}.xml')
    (OUT/'rules.json').write_text(json.dumps({'thresholds': thresholds, 'particles': particles,
        'sources': sources, 'adapter': 'GpuParticleDistort medium LOD, 30 native frames; no scene-depth soft particles'},
        ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Imported', len(particles), 'particle templates and 5 retail textures')

if __name__ == '__main__':
    main()
