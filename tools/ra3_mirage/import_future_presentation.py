"""Future Tank native draw models, particle XML and LaserDraw constants."""
import json, struct, hashlib, shutil
from xml.etree import ElementTree as ET
from import_expansion import ROOT, XML, SRC, DEST, cv
from import_uprising_runtime import decode_delta
NS={'s':'uri:ea.com:eala:asset'}

def main():
    sources=[SRC,ROOT/'refs/ra3-expansion/future-extra/converted']
    out=DEST/'future/fx';out.mkdir(parents=True,exist_ok=True);hashes={}
    def locate(relative):
        return next(p/relative for p in sources if (p/relative).exists())
    def read(p):
        hashes[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
        return json.loads(p.read_text())
    def copy_texture(name):
        p=locate('textures/Texture_'+name+'.png');shutil.copyfile(p,out/(name+'.png'))
        hashes[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest();return name+'.png'
    def tree(n):return {'tag':n.tag.split('}')[-1],'attrs':dict(n.attrib),'children':[tree(c) for c in n]}
    def xml(p):
        hashes[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest();return ET.parse(p).getroot()
    models={}
    for name in ['EXFUTURETANKCHARGE','FXFUTUREPROJECTILE','FXFUTUREPROJECTILE_VET','FXFUTUREPROJECTILE02','FXFUTUREPROJECTILE02_VET']:
        hpath=locate('hierarchies/W3DHierarchy_'+name+'.json');media=hpath.parents[1]
        manifest=read(media.parent/'extraction.json');assets={a['name']:a for a in manifest['assets']}
        ids={(a['type'],a['instance']):a['name'] for a in manifest['assets']}
        container=assets['W3DContainer:'+name]
        raw=next(f['file'] for f in manifest['files'] if f['asset']==container['name'] and f['part']=='bin')
        raw_path=media.parent/raw;b=raw_path.read_bytes()
        hashes[str(raw_path.relative_to(ROOT))]=hashlib.sha256(b).hexdigest()
        count,ptr=struct.unpack_from('<II',b,8);attachments={}
        for i in range(count):
            bone,_,_,ref=struct.unpack_from('<4I',b,ptr+16*i)
            attachments[ids[tuple(container['references'][ref-1])].replace(':','_',1)]=bone
        bones=[dict(parent=b['parent'],position=cv(b['translation']),rotation=cv(b['rotation_xyzw'][:3])+[b['rotation_xyzw'][3]]) for b in read(hpath)['bones']]
        parts=[]
        for p in sorted((media/'meshes').glob('W3DMesh_'+name+'.*.json')):
            r=read(p);a=r['attributes'];assert not r['bone_palette']
            textures={}
            for key,val in r['material']['constants'].items():
                if isinstance(val,dict) and val.get('asset','').startswith('Texture:'):textures[key]=copy_texture(val['asset'].split(':',1)[1])
            parts.append(dict(name=p.stem,bone=attachments[p.stem],vertices=[x for v in a['p0'] for x in cv(v)],normals=[x for v in a['n0'] for x in cv(v)],uv=[x for v in a['t0'] for x in v],uv2=[x for v in a.get('t1',a['t0']) for x in v],colors=a.get('c0',[]),indices=r['indices'],material=r['material'],textures=textures))
        clip={}
        ap=media/'animations'/('W3DAnimation_'+name+'.json')
        if ap.exists():
            r=read(ap);channels=[]
            for c in r['channels']:
                assert c['channel_type_name']=='Visibility', 'Add native transform channel support before import'
                if c['format']=='AnimationChannelDelta':values=decode_delta(c,r['frames'])
                else:
                    keys=c['frame_and_binary_flag'];values=[]
                    for frame in range(r['frames']):
                        k=next((i for i in reversed(range(len(keys))) if (keys[i]&0x7fff)<=frame),0)
                        values.append([c['values'][k]])
                channels.append(dict(bone=c['pivot'],values=[v[0] for v in values]))
            clip=dict(frames=r['frames'],fps=r['fps'],channels=channels)
        models[name.lower()]=dict(bones=bones,parts=parts,clip=clip)
    particles={}
    for p in (XML/'FXParticleSystems').glob('AlliedFuture*.xml'):
        if p.stem=='AlliedFutureRays':continue # Not referenced by either active weapon/draw.
        # SAGE asset identifiers are case-insensitive (the SDK even references
        # Hit_LightVet while declaring Hit_Lightvet).
        n=xml(p).find('s:FXParticleSystemTemplate',NS);particles[n.get('id').lower()]=tree(n)
        if n.get('ParticleTexture'):copy_texture(n.get('ParticleTexture'))
    obj=xml(XML/'EP1/Allied/Units/AlliedFutureTank.xml')
    lasers=[tree(n) for n in obj.findall('.//s:LaserDraw',NS)]
    for laser in lasers:
        for n in laser['children']:
            if n['tag']=='FXShader':
                for p in obj.findall('.//s:LaserDraw/s:FXShader/s:Constants/s:Texture/s:Value',NS):copy_texture(p.text)
    output=dict(models=models,particles=particles,lasers=lasers,beam=tree(obj.find('.//s:BeamSpecialAbilityUpdate',NS)),just_built=obj.find('s:GameObject',NS).get('JustBuiltTime'))
    (out/'presentation.json').write_text(json.dumps(output,separators=(',',':')))
    (out/'provenance.json').write_text(json.dumps({'sources':hashes,'generated_sha256':hashlib.sha256((out/'presentation.json').read_bytes()).hexdigest()},indent=2))
    print('Future presentation:',len(models),'models',sum(len(m['parts']) for m in models.values()),'meshes',len(particles),'particle systems')

if __name__=='__main__':main()
