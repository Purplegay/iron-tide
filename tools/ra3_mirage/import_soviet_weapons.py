"""Import combat effect definitions and their transitive retail art and audio."""
from pathlib import Path
import json, shutil, wave, hashlib
import xml.etree.ElementTree as ET
from import_reaper_fx import tree
from import_expansion import cv, poid, rotate, mul

ROOT = Path(__file__).resolve().parents[2]
XML = ROOT/'refs/ea-modding-support/Uprising/Xml'
DEST = ROOT/'iron_tide/assets/ra3/soviet/tank_fx'
sources = [ROOT/'refs/ra3-soviet'/p for p in ('tank-weapons','grinder','tank-states')]

def main():
    DEST.mkdir(exist_ok=True)
    data = dict(effects={}, particles={}, inputs={}, damage={})
    def parse(rel):
        file = XML/rel
        data['inputs'][rel] = hashlib.sha256(file.read_bytes()).hexdigest()
        return ET.parse(file)
    def copy(kind, file, name):
        for source in sources:
            p = source/'converted'/kind/file
            if p.exists():
                shutil.copyfile(p, DEST/name)
                return name
        raise FileNotFoundError(file)
    def texture(name):
        return copy('textures','Texture_'+name+'.png',name+'.png')
    tanks = [parse('Soviet/Units/SovietAntiVehicleVehicleTech%d.xml'%tier) for tier in (2,3)]
    weapon = parse('GlobalData/Weapon.xml')
    cannon = weapon.find(".//*[@id='SovietAntiVehicleVehicleTech3Cannon']")
    zap = weapon.find(".//*[@id='SovietAntiVehicleVehicleTech2TeslaGun']")
    prop = parse('Soviet/Props/SovietAntiVehicleVehicleTech3Projectile.xml')
    data['cannon'] = dict(fire=cannon.get('FireFX'), hero_fire=cannon.get('FireVeteranFX'), impacts=[n.get('FX') for n in prop.findall('.//{*}Event')])
    data['tesla'] = zap.get('FireFX')
    draw=tanks[1].find('.//{*}TruckDraw')
    data['recoil']={k:float(draw.get(k)) for k in ('InitialRecoilSpeed','MaxRecoilDistance','RecoilDamping','RecoilSettleSpeed')}
    for shader in ('Laser.fx','GpuParticleDistort.fx','GpuParticlePerpendicularBottom.fx'):
        data['inputs']['Shaders/'+shader]=hashlib.sha256((XML.parent/'Shaders'/shader).read_bytes()).hexdigest()
    data['lasers']=[]
    for layer in tanks[1].findall('.//{*}LaserDraw'):
        constants=layer.find('.//{*}Constants')
        maps=[texture(n.find('{*}Value').text) for n in constants.findall('{*}Texture')]
        emissive=[float(v.text) for v in constants.findall("./{*}Float[@Name='ColorEmissive']/{*}Value")]
        data['lasers'].append(dict(attrs=layer.attrib,maps=maps,emissive=emissive))
    data['tips']=[n.text for n in tanks[1].findall('.//{*}LaserEndParticleSystem')]
    ids={data['tesla'],data['cannon']['fire'],data['cannon']['hero_fire'],*data['cannon']['impacts'],'FX_Sov_TB_Grinder'}
    for group in parse('GlobalData/DamageFX.xml').getroot():
        for c in group:
            if c.get('Type') in ('SOVIET_TESLA','SOVIET_CANNON'):
                data['damage'].setdefault(group.get('id'),{})[c.get('Type')]=dict(c.attrib)
                ids.update(v for k,v in c.attrib.items() if k.endswith('FX'))
    particles={'SovietTesla_EMP','Sov_Apoc_TB_Spark','Sov_Apoc_TB_Glow',*data['tips']}
    sounds={'SOV_Apocalypse_WeaponHarpoon'}
    data['mounts']={}
    retail=ROOT/'refs/ra3-soviet/retail/converted'
    deployed = parse('EP1/Soviet/Units/SovietHeavyWalkerDeployedTurret.xml')
    for uid,unit in zip(('R3TESLA','R3APOC','R3REAPERTURRET'),[*tanks,deployed]):
        mounts=data['mounts'][uid]={}
        draws=unit.find('.//{*}Draws')
        for n in draws.iter():
            condition=n.get('ConditionsYes','')
            if condition not in ('DAMAGED','REALLYDAMAGED','MOVING','ACCELERATE','WEAPONSTATE_ONE MOVING','WEAPONSTATE_ONE ACCELERATE'):continue
            bucket=mounts.setdefault(condition,[])
            for ps in n.findall('{*}ParticleSysBone'):
                bucket.append(dict(bone=ps.get('BoneName'),fx=ps.get('FXParticleSystemTemplate')))
                particles.add(ps.get('FXParticleSystemTemplate'))
            for tex in n.findall('{*}Texture'):
                mounts['skin']=dict(original=tex.get('Original'),damaged=tex.get('New'))
                name=tex.get('New')+'.png'
                shutil.copyfile(retail/'textures'/('Texture_'+name),DEST/name)
    # The Apocalypse's damage socket is in the separate FX skeleton.
    fxrig=json.loads((retail/'hierarchies/W3DHierarchy_SUANTIVEHICLEVEHICLETECH3_FX.json').read_text())
    poses=[]
    for bone in fxrig['bones']:
        t,q=bone['translation'],bone['rotation_xyzw']
        if bone['parent']>=0:
            pt,pq=poses[bone['parent']]
            t=[a+b for a,b in zip(pt,rotate(pq,t))];q=mul(pq,q)
        poses.append((t,q))
        if bone['name_hash']==poid('FX_BONE01'):data['apoc_damage_socket']=cv(t)
    assert 'apoc_damage_socket' in data
    for name in ('FXListAllied','FXListSoviet'):
        for n in parse('GlobalData/'+name+'.xml').getroot():
            if n.get('id') not in ids:continue
            data['effects'][n.get('id')]=tree(n)
            particles.update(x.get('Particle') for x in n.findall('.//{*}ParticleSystem'))
            sounds.update(x.get('Value') for x in n.findall('.//{*}Sound'))
    assert ids==data['effects'].keys()
    for id in sorted(particles):
        n=parse('FXParticleSystems/'+id+'.xml').find('{*}FXParticleSystemTemplate')
        data['particles'][id]=tree(n)
        if n.get('ParticleTexture'):texture(n.get('ParticleTexture'))
        for gpu in n.findall('.//{*}Gpu'):
            if gpu.get('DetailTexture'):texture(gpu.get('DetailTexture'))
        if n.get('Type')=='DRAWABLE':
            key=n.get('Drawable').upper()
            mesh=json.loads((sources[0]/'converted/meshes'/('W3DMesh_'+key+'.json')).read_text())
            a=mesh['attributes']; mat=mesh['material']
            part=dict(vertices=sum([cv(v) for v in a['p0']],[]),normals=sum([cv(v) for v in a['n0']],[]),uv=sum(a['t0'],[]),uv2=sum(a.get('t1',a['t0']),[]),colors=a.get('c0',[]),indices=mesh['indices'],material=mat,textures={k:texture(v['asset'].split(':')[1]) for k,v in mat['constants'].items() if isinstance(v,dict) and 'asset' in v and v['asset'].startswith('Texture:')})
            (DEST/(key.lower()+'.json')).write_text(json.dumps(part,separators=(',',':')))
    rows={}
    for src in sources:
        for a in json.loads((src/'extraction.json').read_text())['assets']:rows[a['name']]=a
    by_id={(a['type'],a['instance']):k for k,a in rows.items()}
    audio=dict(specs={},entries={})
    for id in sorted(sounds):
        todo=[next(k for k in rows if k.split(':')[-1]==id)];seen=set();clips=[]
        while todo:
            key=todo.pop()
            if key in seen:continue
            seen.add(key)
            if key.startswith('AudioFile:'):
                file=key.replace(':','_')+'.wav';copy('audio',file,file);k=key.split(':')[1].lower()
                with wave.open(str(DEST/file)) as w:audio['entries'][k]=dict(file='res://assets/ra3/soviet/tank_fx/'+file,sampleRate=w.getframerate(),channels=w.getnchannels(),durMs=round(w.getnframes()*1000/w.getframerate()))
                clips.append(k)
            else:todo.extend(by_id[tuple(v)] for v in rows[key]['references'] if tuple(v) in by_id)
        assert clips,id
        audio['specs']['RA3_TANK_'+id]=dict(sounds=sorted(clips),volume=85,priority=9,loop=False)
    (ROOT/'iron_tide/data/ra3_tank_sounds.json').write_text(json.dumps({'sounds':audio},indent=2))
    (DEST/'source.json').write_text(json.dumps(data,separators=(',',':')))

if __name__=='__main__':main()

