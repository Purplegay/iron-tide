"""Copy official Bomber death FX declarations and scoped retail textures."""
import hashlib,json,shutil
from pathlib import Path
from xml.etree import ElementTree as ET
ROOT=Path(__file__).resolve().parents[2]
XML=ROOT/'refs/ea-modding-support/Uprising/Xml'
OUT=ROOT/'iron_tide/assets/ra3/expansion/crash'
NS={'s':'uri:ea.com:eala:asset'}
def node(e):return dict(tag=e.tag.split('}')[-1],attrs=e.attrib,children=[node(c) for c in e])
def main():
    OUT.mkdir(parents=True,exist_ok=True);sources={};particles={}
    def record(p):sources[p.relative_to(ROOT).as_posix()]=hashlib.sha256(p.read_bytes()).hexdigest()
    source=XML/'GlobalData/FXListAllied.xml';record(source)
    fx=ET.parse(source).getroot().find("s:FXList[@id='FX_AlliedBomberDie']",NS)
    names=[e.get('Particle') for e in fx.findall('.//s:ParticleSystem',NS)]
    for name in names:
        p=XML/'FXParticleSystems'/(name+'.xml');record(p)
        data=ET.parse(p).find('s:FXParticleSystemTemplate',NS);particles[name]=node(data)
        texture=data.get('ParticleTexture')
        choices=[ROOT/'refs/ra3-expansion'/f/'converted/textures'/('Texture_'+texture+'.png') for f in ['crash-media','uprising','damage-state']]
        p=next(p for p in choices if p.exists());record(p);shutil.copyfile(p,OUT/(texture+'.png'))
    (OUT/'effects.json').write_text(json.dumps(dict(effect=node(fx),particles=particles,sources=sources),indent=2),encoding='utf-8')
    print('Imported four official crash FX systems and retail textures')
if __name__=='__main__':main()
