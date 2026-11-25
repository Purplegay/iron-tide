"""Install omitted Mirage model FX and disguise variants from local retail data."""
import hashlib
import json
import shutil
from pathlib import Path
from xml.etree import ElementTree as ET
from import_expansion import rotate, mul, cv

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'refs/ra3-mirage/uprising/converted'
DEST=ROOT/'iron_tide/assets/ra3/mirage/completion'
XML=ROOT/'refs/ea-modding-support/Uprising/Xml'
NS={'s':'uri:ea.com:eala:asset'}

def main():
    DEST.mkdir(parents=True,exist_ok=True)
    hashes={}
    def read(path):
        hashes[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
        return json.loads(path.read_text())
    bones=read(ROOT/'iron_tide/assets/ra3/mirage/native/skin.json')['bones']
    glob=[]
    for bone in bones:
        t,q=bone['position'],bone['rotation']
        if bone['parent']>=0:
            pt,pq=glob[bone['parent']];t=[x+y for x,y in zip(pt,rotate(pq,t))];q=mul(pq,q)
        glob.append((t,q))
    def mesh(name,skinned=False):
        raw=read(SRC/'meshes'/('W3DMesh_'+name+'.json'));a=raw['attributes']
        vertices=[];normals=[];joints=[];weights=[]
        for i,v in enumerate(a['p0']):
            v=cv(v);n=cv(a['n0'][i])
            if skinned:
                bone=raw['bone_palette'][a['i0'][i][0]] if raw['bone_palette'] else 10
                t,q=glob[bone];v=[x+y for x,y in zip(t,rotate(q,v))];n=rotate(q,n)
                joints.extend([bone,0,0,0]);weights.extend([1,0,0,0])
            vertices.extend(v);normals.extend(n)
        textures={}
        for channel,value in raw['material']['constants'].items():
            if isinstance(value,dict) and value.get('asset','').startswith('Texture:'):
                texture=value['asset'].split(':',1)[1]+'.png';source=SRC/'textures'/('Texture_'+texture)
                shutil.copyfile(source,DEST/texture);hashes[str(source.relative_to(ROOT))]=hashlib.sha256(source.read_bytes()).hexdigest();textures[channel]=texture
        return dict(name=name,vertices=vertices,normals=normals,uv=[x for v in a['t0'] for x in v],uv2=[x for v in a.get('t1',a['t0']) for x in v],colors=a.get('c0',[]),indices=raw['indices'],bones=joints,weights=weights,material=raw['material'],textures=textures)
    parts=[mesh('AUANTIVEHICLEVEHICLETECH3_SKN.'+name,True) for name in ['LIGHTNINGFX','GLOWFX','PLASMAFX']]
    props={key:mesh(name) for key,name in [('Tree01','AP_MIRAGETREE01'),('Tree02','AP_MIRAGETREE02'),('Rock01','AP_MIRAGEROCK01'),('Truck01','AP_MIRAGETRUCK01')]}
    def record(n):return dict(tag=n.tag.split('}')[-1],attrs=n.attrib,children=[record(c) for c in n])
    rays=[]
    for name in ['Primage_Disguise_Rays','Primage_Disguise_Rays02']:
        path=XML/'FXParticleSystems'/(name+'.xml');hashes[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
        rays.append(record(ET.parse(path).getroot().find('s:FXParticleSystemTemplate',NS)))
    unit=ET.parse(XML/'Allied/Units/AlliedAntiVehicleVehicleTech3.xml').getroot().find('s:GameObject',NS)
    terrain={n.get('TerrainClass'):n.get('ObjectTemplate').removeprefix('PrimageDisguise_') for n in unit.findall('.//s:SpecialDisguiseUpdate/s:TerrainData',NS)}
    out=dict(parts=parts,props=props,ray_mesh=mesh('FXMIRAGERAYS'),ray_particles=rays,terrain=terrain,source_sha256=hashes)
    (DEST/'media.json').write_text(json.dumps(out,separators=(',',':')),encoding='utf-8')
    print('Imported 3 model FX, 4 disguises, 2 ear ray declarations; source hashes',len(hashes))

if __name__=='__main__':main()
