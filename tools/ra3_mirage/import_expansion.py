"""Convert extracted Uprising vehicle skins and clips without an intermediate DCC.

Inputs are retained by extract_uprising.py/convert_uprising_media.py. Coordinate
conversion is SAGE (x,y,z) -> Godot (x,z,-y); native reference hashes are retained.
"""
from pathlib import Path
import hashlib, json, math, re, shutil, struct
from xml.etree import ElementTree as ET
from import_uprising_runtime import decode_delta

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'refs/ra3-expansion/uprising/converted'
DEST = ROOT / 'iron_tide/assets/ra3/expansion'
XML = ROOT / 'refs/ea-modding-support/Uprising/Xml'

def cv(v): return [v[0], v[2], -v[1]]
def rotate(q,v):
    x,y,z,w=q; a,b,c=v
    u,v,t=2*(y*c-z*b),2*(z*a-x*c),2*(x*b-y*a)
    return [a+w*u+y*t-z*v,b+w*v+z*u-x*t,c+w*t+x*v-y*u]
def mul(a,b):
    x,y,z,w=a; X,Y,Z,W=b
    return [w*X+x*W+y*Z-z*Y,w*Y-x*Z+y*W+z*X,w*Z+x*Y-y*X+z*W,w*W-x*X-y*Y-z*Z]
def poid(s):
    # SAGE Poid uses the 32-bit SuperFastHash string variant (case-folded names).
    b=s.lower().encode(); h=len(b); mask=0xffffffff; p=0
    while p+4<=len(b):
        h=(h+int.from_bytes(b[p:p+2],'little'))&mask
        h=(h^((int.from_bytes(b[p+2:p+4],'little')^(h<<5))<<11))&mask
        h=(h+(h>>11))&mask; p+=4
    tail=b[p:]
    if len(tail)==1:
        h=(h+tail[0])&mask;h=(h^(h<<10))&mask;h=(h+(h>>1))&mask
    elif len(tail)>=2:
        h=(h+int.from_bytes(tail[:2],'little'))&mask
        if len(tail)==2:h=(h^(h<<11))&mask;h=(h+(h>>17))&mask
        else:h=(h^((h^(tail[2]<<2))<<16))&mask;h=(h+(h>>11))&mask
    h=(h^(h<<3))&mask;h=(h+(h>>5))&mask;h=(h^(h<<2))&mask
    h=(h+(h>>15))&mask;return f'{(h^(h<<10))&mask:08x}'

def main():
    DEST.mkdir(parents=True,exist_ok=True)
    extraction=json.loads((SRC.parent/'extraction.json').read_text())
    assets={a['name']:a for a in extraction['assets']}
    ids={(a['type'],a['instance']):a['name'] for a in extraction['assets']}
    raw_files={(a['asset'],a['part']):a['file'] for a in extraction['files']}
    def container_bones(name):
        a=assets['W3DContainer:'+name]
        b=(SRC.parent/raw_files[a['name'],'bin']).read_bytes()
        count,ptr=struct.unpack_from('<II',b,8);result={}
        for i in range(count):
            bone,length,string,ref=struct.unpack_from('<4I',b,ptr+16*i)
            result[ids[tuple(a['references'][ref-1])].replace(':','_',1)]=bone
        return result
    names={}
    for p in (XML/'EP1/Allied').rglob('*.xml'):
        for name in re.findall(r'\b(?:FX[_A-Za-z0-9]+|Bone[_A-Za-z0-9]+|B_[A-Za-z0-9]+|Turret[_A-Za-z0-9]+)\b',p.read_text(encoding='utf-8-sig'),re.I):
            names[poid(name)]=name
    provenance={}
    def copy(p,target):
        target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
        provenance[str(target.relative_to(DEST))]=dict(source=str(p.relative_to(ROOT)),sha256=hashlib.sha256(p.read_bytes()).hexdigest())
    def read(p):
        provenance[str(p.relative_to(ROOT))]=dict(sha256=hashlib.sha256(p.read_bytes()).hexdigest())
        return json.loads(p.read_text())
    for stem,key in [('AUFUTURETANK','future'),('AUGUNSHIP','harbinger')]:
        folder=DEST/key;folder.mkdir(exist_ok=True)
        raw=read(SRC/'hierarchies'/f'W3DHierarchy_{stem}_SKL.json')['bones']
        bones=[];glob=[];fixups=[]
        for i,b in enumerate(raw):
            t=b['translation'];q=b['rotation_xyzw'];parent=b['parent']
            bones.append(dict(name=names.get(b['name_hash'],'bone_'+b['name_hash']),hash=b['name_hash'],parent=parent,position=cv(t),rotation=cv(q[:3])+[q[3]]))
            if parent>=0:
                pt,pq=glob[parent];t=[x+y for x,y in zip(pt,rotate(pq,t))];q=mul(pq,q)
            glob.append((t,q));fixups.append(struct.unpack('<16f',bytes.fromhex(b['remaining_transform_bytes'])))
        meshes=[]
        attachments=container_bones(stem+'_SKN')
        for path in (SRC/'meshes').glob(f'W3DMesh_{stem}_SKN.*.json'):
            if stem!='AUGUNSHIP' and any(s in path.name for s in ['FX','CYLINDER']):continue
            r=read(path);a=r['attributes'];palette=r['bone_palette'];vertices=[];normals=[];joints=[];weights=[]
            for i,v in enumerate(a['p0']):
                bone=palette[a['i0'][i][0]] if palette else attachments[path.stem]
                assert 'w0' not in a, 'weighted skin needs explicit multi-influence conversion'
                # Compiled vertex positions already include the authoring fixup.
                # Applying it a second time stretches the Future Tank turret.
                t,q=glob[bone];n=a['n0'][i]
                vertices.extend(cv([x+y for x,y in zip(t,rotate(q,v))]));normals.extend(cv(rotate(q,n)))
                joints.extend([bone,0,0,0]);weights.extend([1.,0.,0.,0.])
            source_min=r['source_bounds'][:3];source_max=r['source_bounds'][3:]
            converted_min=[source_min[0],source_min[2],-source_max[1]]
            converted_max=[source_max[0],source_max[2],-source_min[1]]
            # Skinned bounds are in bind space; rigid container parts declare local bounds.
            bounded=vertices if palette else [x for v in a['p0'] for x in cv(v)]
            error=max(abs(actual-expected) for k in range(3) for actual,expected in [(min(bounded[k::3]),converted_min[k]),(max(bounded[k::3]),converted_max[k])])
            assert error<0.002,(path.name,'compiled bind bounds mismatch',error)
            material={}
            for channel in ['DiffuseTexture','NormalMap','SpecMap','Texture_0','Texture_1','Texture_2']:
                texture=r['material']['constants'].get(channel,{}).get('asset','').removeprefix('Texture:')
                if texture:
                    copy(SRC/'textures'/f'Texture_{texture}.png',folder/(texture+'.png'));material[channel]=texture+'.png'
            meshes.append(dict(name=path.stem,vertices=vertices,normals=normals,uv=[x for v in a['t0'] for x in v],uv2=[x for v in a.get('t1',a['t0']) for x in v],colors=a.get('c0',[]),bones=joints,weights=weights,indices=r['indices'],material=material,native_material=r['material']))
        clips={}
        for path in (SRC/'animations').glob(f'W3DAnimation_{stem}_*.json'):
            r=read(path)
            if not r['hierarchy'].endswith(stem+'_SKL'):continue
            channels=[]
            for c in r['channels']:
                if c['format']=='AnimationChannelDelta':values=decode_delta(c,r['frames'])
                else:
                    values=[];keys=c['frame_and_binary_flag'];size=c['vector_length']
                    for frame in range(r['frames']):
                        index=next((i for i in reversed(range(len(keys))) if (keys[i]&0x7fff)<=frame),0)
                        values.append(c['values'][index*size:(index+1)*size])
                channels.append(dict(bone=c['pivot'],type=c['channel_type_name'],first=0,frames=values if c['vector_length']>1 else [v[0] for v in values]))
            clips[path.stem.removeprefix('W3DAnimation_'+stem+'_')]=dict(frames=r['frames'],fps=r['fps'],channels=channels)
        (folder/'skin.json').write_text(json.dumps(dict(bones=bones,meshes=meshes),separators=(',',':')))
        (folder/'animations.json').write_text(json.dumps(clips,separators=(',',':')))
        # Native destruction geometry, grouped by the original rigid body bones.
        collapse_name='AlliedFutureTank_Collapse' if key=='future' else 'AlliedGunshipAircraft_Collapse'
        collapse=ET.parse(XML/'EP1/Allied/Props'/(collapse_name+'.xml')).getroot()
        ns={'s':'uri:ea.com:eala:asset'}
        masses={poid(n.get('BoneName')):float(n.get('Mass')) for n in collapse.findall('.//s:BoneVolume',ns)}
        wreck_bones=read(SRC/'hierarchies'/f'W3DHierarchy_{stem}_COL.json')['bones'];wg=[]
        for b in wreck_bones:
            t=b['translation'];q=b['rotation_xyzw'];parent=b['parent']
            if parent>=0:pt,pq=wg[parent];t=[x+y for x,y in zip(pt,rotate(pq,t))];q=mul(pq,q)
            wg.append((t,q))
        pieces=[]
        attachments=container_bones(stem+'_COL')
        for path in (SRC/'meshes').glob(f'W3DMesh_{stem}_COL.*.json'):
            r=read(path);a=r['attributes'];palette=r['bone_palette'];owners=[];positions=[];normals=[]
            for i,v in enumerate(a['p0']):
                b=palette[a['i0'][i][0]] if palette else attachments[path.stem];t,q=wg[b]
                positions.append(cv([x+y for x,y in zip(t,rotate(q,v))]));normals.append(cv(rotate(q,a['n0'][i])))
                while b>=0 and wreck_bones[b]['name_hash'] not in masses:b=wreck_bones[b]['parent']
                assert b>=0,(path.name,'no collapse body');owners.append(b)
            groups={}
            for i in range(0,len(r['indices']),3):
                triangle=r['indices'][i:i+3];assert len({owners[v] for v in triangle})==1
                groups.setdefault(owners[triangle[0]],[]).extend(triangle)
            for b,indices in groups.items():
                used=sorted(set(indices));remap={old:new for new,old in enumerate(used)};center=cv(wg[b][0])
                pieces.append(dict(name=wreck_bones[b]['name_hash'],mass=masses[wreck_bones[b]['name_hash']],treads='TREAD' in path.name,center=center,vertices=[positions[i][k]-center[k] for i in used for k in range(3)],normals=[x for i in used for x in normals[i]],uv=[x for i in used for x in a['t0'][i]],indices=[remap[i] for i in indices]))
        (folder/'wreck.json').write_text(json.dumps(dict(pieces=pieces,draw_delay=5.,fade_seconds=4.,death_age=4.5,sink_delay=1.,sink_rate=1.5),separators=(',',':')))
        burnt='AUFutureTank_D' if key=='future' else 'AUGunship_D'
        copy(SRC/'textures'/('Texture_'+burnt+'.png'),folder/'burnt.png')
        for kind in ['Button','Portrait']:
            name='AlliedFutureTank' if key=='future' else 'AlliedHarbingerGunship'
            copy(SRC/'icons'/f'PackedTextureImage_{kind}_{name}.png',folder/(kind.lower()+'.png'))
        print(key,len(bones),'bones',len(meshes),'meshes',len(clips),'animations',[(b['name'],i) for i,b in enumerate(bones) if not b['name'].startswith('bone_')])
    copy(SRC/'icons/PackedTextureImage_AUA_FutureTank_RiotBeam.png',DEST/'future/ability.png')
    for name in ['FXAlliedFutureLaser','FXAlliedFutureElec','FXPrismMuzzle02','FXAlliedProtonColliderHitCoreDiffuse','FXAlliedProtonColliderHitDiffuse']:
        copy(SRC/'textures'/('Texture_'+name+'.png'),DEST/'fx'/(name+'.png'))
    fx_meshes=[('FXFUTUREPROJECTILE.GEOSPHERE01','neutron'),('AUGUNSHIPPROJECTILE.PROJECTILE01','shell'),('AUGUNSHIPPROJECTILE_VET.PROJECTILE01','shell_vet')]
    for path in sorted((SRC/'meshes').glob('W3DMesh_FXALLIEDPROTONCOLLIDERHIT*.json')):
        fx_meshes.append((path.stem.removeprefix('W3DMesh_'),path.stem.removeprefix('W3DMesh_').split('.')[0].lower()))
    for name,key in fx_meshes:
        r=read(SRC/'meshes'/('W3DMesh_'+name+'.json'));a=r['attributes'];assert not r['bone_palette']
        textures={}
        for key_,value in r['material']['constants'].items():
            if isinstance(value,dict) and value.get('asset','').startswith('Texture:'):
                texture=value['asset'].split(':',1)[1];copy(SRC/'textures'/('Texture_'+texture+'.png'),DEST/'fx'/(texture+'.png'));textures[key_]=texture+'.png'
        output=dict(vertices=[x for v in a['p0'] for x in cv(v)],normals=[x for v in a['n0'] for x in cv(v)],uv=[x for v in a['t0'] for x in v],uv2=[x for v in a.get('t1',a['t0']) for x in v],colors=a.get('c0',[]),indices=r['indices'],material=r['material'],textures=textures)
        (DEST/'fx'/(key+'.json')).write_text(json.dumps(output,separators=(',',':')))
    # Preserve the actual FXList references and full particle fields, not guessed rings.
    def tree(node):
        return dict(tag=node.tag.split('}')[-1],attrs=dict(node.attrib),children=[tree(c) for c in node])
    ns={'s':'uri:ea.com:eala:asset'}
    lists=ET.parse(XML/'GlobalData/FXListAllied.xml').getroot()
    effects={}
    for name in ['FX_AlliedGunshipProtonHit','FX_AlliedGunshipProtonHitVet','FX_Allied_Gunship_Fire']:
        node=lists.find(f"s:FXList[@id='{name}']",ns);effects[name]=tree(node)
    particles={}
    for name in {n.get('Particle') for n in lists.findall('.//s:ParticleSystem',ns) if n.get('Particle','').startswith(('FXAlliedGunship','AlliedGunship'))} | {'AlliedGunshipFireLight'}:
        path=XML/'FXParticleSystems'/(name+'.xml')
        node=ET.parse(path).getroot().find('s:FXParticleSystemTemplate',ns);particles[name]=tree(node)
        provenance[str(path.relative_to(ROOT))]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        texture=node.get('ParticleTexture')
        if texture:copy(SRC/'textures'/('Texture_'+texture+'.png'),DEST/'fx'/(texture+'.png'))
    trail=XML/'FXParticleSystems/FireHawkConTrail.xml'
    particles['FireHawkConTrail']=tree(ET.parse(trail).getroot().find('s:FXParticleSystemTemplate',ns))
    provenance[str(trail.relative_to(ROOT))]={'sha256':hashlib.sha256(trail.read_bytes()).hexdigest()}
    for name in ['FXTracer','FXTracerHeroic','FXMissileStreak']:
        copy(ROOT/'refs/ra3-expansion/gunship-trails/converted/textures'/('Texture_'+name+'.png'),DEST/'fx'/(name+'.png'))
    gunship=ET.parse(XML/'EP1/Allied/Units/AlliedGunshipAircraft.xml').getroot()
    tracers=[tree(n) for n in gunship.findall('.//s:TracerModelDraw',ns)]
    (DEST/'fx/gunship_effects.json').write_text(json.dumps(dict(effects=effects,particles=particles,tracers=tracers),separators=(',',':')))
    generated={str(p.relative_to(DEST)):hashlib.sha256(p.read_bytes()).hexdigest() for p in DEST.rglob('*.json') if p.name!='provenance.json'}
    (DEST/'provenance.json').write_text(json.dumps(dict(source='Steam Uprising 1.1',official_xml_commit='3aad8e412961ab543192ae70f8503dc8e178e095',files=provenance,generated=generated),indent=2))

if __name__=='__main__':main()
