"""Import Bibber Upheaval gunship draw states and inherited EA bullet-hit assets.

Upheaval references base-game FX rather than bundling copies of those textures.
The three base textures must first be extracted from the local retail Uprising.
"""
import hashlib
import json
import shutil
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[2]
EA = ROOT / 'refs/ea-modding-support/Uprising'
OUT = ROOT / 'iron_tide/assets/ra3/expansion/fx'
PACKAGE = ROOT / 'refs/ra3-expansion/upheaval/ra3-upheaval-source-code.zip'
NS = {'s': 'uri:ea.com:eala:asset'}


def node(e):
    return {'tag': e.tag.split('}')[-1], 'attrs': e.attrib,
            'children': [node(c) for c in e]}


def main():
    sources = {}
    def record(path):
        sources[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    record(PACKAGE)
    with ZipFile(PACKAGE) as archive:
        prefix = 'Upheaval/Data/Mod/Units/Harbinger Gunship/'
        raw = archive.read(prefix + 'GameObject.xml')
        game = ET.fromstring(raw)
        sources[prefix + 'GameObject.xml'] = hashlib.sha256(raw).hexdigest()
        weapons = ET.fromstring(archive.read(prefix + 'WeaponTemplate.xml'))
        # Verify our existing impact import against ALL Upheaval particle definitions.
        particles = ET.fromstring(archive.read(prefix + 'FXParticleSystemTemplate.xml'))
        impact = json.loads((OUT / 'gunship_effects.json').read_text())
        for e in particles:
            if e.get('id') in impact['particles']:
                assert node(e) == impact['particles'][e.get('id')], e.get('id')
        # The native meshes have not acquired an extra scale during retail conversion.
        for name, mesh in [('fxalliedprotoncolliderhitshockwavev', 'FXALLIEDPROTONCOLLIDERHITSHOCKWAVEV.SPHERE01'),
                           ('fxalliedprotoncolliderhitcorev', 'FXALLIEDPROTONCOLLIDERHITCOREV.GEOSPHERE01')]:
            raw = archive.read('Upheaval/Art/Units/Harbinger Gunship/' + mesh + '.w3x')
            sources[mesh + '.w3x'] = hashlib.sha256(raw).hexdigest()
            vertices = ET.fromstring(raw).findall('.//s:Vertices/s:V', NS)
            expected = [v for e in vertices for v in (float(e.get('X')),float(e.get('Z')),-float(e.get('Y')))]
            actual = json.loads((OUT/(name+'.json')).read_text())['vertices']
            assert len(expected) == len(actual)
            assert max(abs(a-b) for a,b in zip(expected,actual)) < 0.00001, mesh
    bullet_particles = {}
    for name in ['BulletHitAlliesSpark', 'BulletHitAlliesFlash', 'CritHitS']:
        path = EA / 'Xml/FXParticleSystems' / (name + '.xml')
        record(path)
        bullet_particles[name] = node(ET.parse(path).find('s:FXParticleSystemTemplate', NS))
    for name in ['FXBulletHit', 'FXStreak', 'FXLenzFlare03']:
        path = ROOT / 'refs/ra3-expansion/gunship-weapons/converted/textures' / ('Texture_' + name + '.png')
        record(path)
        shutil.copyfile(path, OUT / (name + '.png'))
    for path in [EA/'Xml/GlobalData/FXListSoviet.xml', EA/'Xml/GlobalData/DamageFX.xml', EA/'Shaders/GpuParticle.fx']:
        record(path)
    rules = dict(tracers=[node(e) for e in game.findall('.//s:TracerModelDraw', NS)],
        turrets=[node(e) for e in game.findall('.//s:WeaponSlotTurret', NS)],
        weapons=[node(e) for e in weapons if e.tag.endswith('WeaponTemplate')],
        particles=bullet_particles, sources=sources,
        adapter='30 Hz cosmetic tracer emission; sweep CPU units unresolved, no guessed sweep motion; native damage rules unchanged')
    (OUT/'gunship_weapons.json').write_text(json.dumps(rules, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Imported Upheaval weapon states, 3 inherited bullet particle systems and 3 retail textures')


if __name__ == '__main__':
    main()
