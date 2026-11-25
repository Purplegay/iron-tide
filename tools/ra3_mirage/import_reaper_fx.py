"""Export Uprising's Reaper rounds, emitter lists and selection state definitions."""
from pathlib import Path
import hashlib,json,shutil,struct,wave
import xml.etree.ElementTree as ET
from import_expansion import cv
ROOT=Path(__file__).resolve().parents[2]
XML=ROOT/'refs/ea-modding-support/Uprising/Xml'
SRC=ROOT/'refs/ra3-soviet/reaper-fx'
C=SRC/'converted'
DEST=ROOT/'iron_tide/assets/ra3/soviet/reaper_fx'
def read(p):return json.loads(p.read_text(encoding='utf8'))
def tree(n):return dict(tag=n.tag.split('}')[-1],attrs=dict(n.attrib),children=[tree(c) for c in n])
def grenade_mounts(unit,slots,hardpoints):
    turrets={n.get('TurretID'):n.get('TurretNameKey') for n in unit.findall('.//{*}Turret')}
    result=[]
    for slot in slots.findall('{*}WeaponSlotTurret'):
        if slot.find('{*}Weapon').get('Template')!='SovietHeavyWalkerGrenadeWeapon':continue
        settings=slot.find('{*}TurretSettings')
        slot_id=slot.get('ID')
        result.append(dict(bone=hardpoints[slot_id],turret=turrets[slot_id],angle=float(settings.get('NaturalTurretAngle').rstrip('d')),
                           clockwise=float(settings.get('MaxDeflectionClockwise').rstrip('d')),anticlockwise=float(settings.get('MaxDeflectionAntiClockwise').rstrip('d')),
                           turn_rate=float(settings.attrib['TurretTurnRate']),recenter_outside=settings.attrib['RecenterWhenOutOfTurnRange']=='true'))
    return result

def main():
    DEST.mkdir(parents=True,exist_ok=True)
    extraction=read(SRC/'extraction.json')
    rows={a['name']:a for a in extraction['assets']}
    ids={(a['type'],a['instance']):a['name'] for a in rows.values()}
    raw={(a['asset'],a['part']):a['file'] for a in extraction['files']}
    inputs={}
    def xml(rel):
        path=XML/rel;inputs[rel]=hashlib.sha256(path.read_bytes()).hexdigest();return ET.parse(path)
    def texture(name):
        dest=DEST/(name+'.png')
        p=C/'textures'/('Texture_'+name+'.png')
        shutil.copyfile(p if p.exists() else land/'converted'/'textures'/p.name,dest)
        return dest.name
    rules={'models':{},'rounds':{},'effects':{},'particles':{},'selection':{}}
    unit=xml('EP1/Soviet/Units/SovietHeavyWalkerVehicle.xml')
    for n in unit.findall('.//{*}AnimationState'):
        state=n.get('StateName')
        if state in ['STATE_bored','STATE_SelectedPose','TRANS_IdleToSelected','TRANS_SelectedToIdle']:
            rules['selection'][state]=[dict(clip=a.get('AnimationName').split('_')[-1],weight=int(a.get('AnimationPriority',1)),blend=float(a.get('AnimationBlendTime',5)),speed_min=float(a.get('AnimationSpeedFactorMin',1)),speed_max=float(a.get('AnimationSpeedFactorMax',1))) for a in n.findall('{*}Animation')]
    slots=xml('EP1/Includes/SovietHeavyWalkerWeaponSet.xml')
    hardpoints={n.get('WeaponSlotID'):n.get('BoneName') for n in unit.findall('.//{*}WeaponLaunchBone')}
    rules['grenade_mounts']=grenade_mounts(unit,slots,hardpoints)
    weapons=xml('EP1/GlobalData/Weapon_EP1.xml')
    lists=xml('GlobalData/FXListSoviet.xml')
    land=SRC.parent/'landing'
    extra=read(land/'extraction.json')
    for a in extra['assets']:
        rows.setdefault(a['name'],a);ids[(a['type'],a['instance'])]=a['name']
    fx={'FX_SovietSickleLand','FX_SOV_ProtoSickle_MoveLand'}
    for kind in ['Grenade','Rocket']:
        stem='SovietHeavyWalker'+kind+'Weapon'
        w=weapons.find(".//{*}WeaponTemplate[@id='%s']"%stem)
        objs=xml('EP1/Soviet/Props/'+stem+'Projectile.xml')
        base,vet=objs.findall('{*}GameObject')
        curve=base.find('.//{*}BezierProjectile')
        def model(n):return n.find('.//{*}Model').get('Name').upper()
        row=dict(model=model(base),hero_model=model(vet),curve=curve.attrib,launch=w.get('FireFX'),hero_launch=w.get('FireVeteranFX'),speed_min=float(w.get('MinWeaponSpeed')),speed_max=float(w.get('MaxWeaponSpeed')),hit=base.find('.//{*}Event').get('FX'),hero_hit=vet.find('.//{*}Event').get('FX'),ground=curve.get('GroundHitFX'),hero_ground=vet.find('.//{*}BezierProjectile').get('GroundHitFX'))
        row['min_range']=float(w.get('MinimumAttackRange'));row['max_range']=float(w.get('AttackRange'))
        row['clip_size']=int(w.get('ClipSize'))
        row['shot_interval']=float(w.find('{*}FiringDuration').get('MinSeconds').rstrip('s'))
        row['reload_seconds']=float(w.find('{*}ClipReloadTime').get('MinSeconds').rstrip('s'))
        fx.update(row[k] for k in ['launch','hero_launch','hit','hero_hit','ground','hero_ground']);rules['rounds'][kind.lower()]=row
    for name in sorted({r[k] for r in rules['rounds'].values() for k in ['model','hero_model']}):
        container='W3DContainer:'+name;b=(SRC/raw[container,'bin']).read_bytes()
        count,ptr=struct.unpack_from('<II',b,8)
        bones=read(C/'hierarchies'/('W3DHierarchy_'+name+'.json'))['bones'];parts=[]
        for i in range(count):
            bone,_,_,ref=struct.unpack_from('<4I',b,ptr+16*i);asset=ids[tuple(rows[container]['references'][ref-1])]
            if not asset.startswith('W3DMesh:'):continue
            mesh=read(C/'meshes'/(asset.replace(':','_')+'.json'));a=mesh['attributes']
            material=mesh['material'];textures={k:texture(v['asset'].split(':')[1]) for k,v in material['constants'].items() if isinstance(v,dict) and v.get('asset','').startswith('Texture:')}
            data=dict(vertices=sum([cv(v) for v in a['p0']],[]),normals=sum([cv(n) for n in a['n0']],[]),uv=sum(a['t0'],[]),uv2=sum(a.get('t1',a['t0']),[]),colors=a.get('c0',[]),indices=mesh['indices'],textures=textures,material=material,bone=bone)
            parts.append(data)
        assert parts and all(b['parent']<=0 for b in bones)
        rig=[dict(parent=b["parent"],position=cv(b['translation']),rotation=cv(b['rotation_xyzw'][:3])+b['rotation_xyzw'][3:]) for b in bones]
        rules['models'][name]=dict(parts=parts,bones=rig)
        if name=='EXSOVIETGRENADE':
            anim=read(C/'animations'/('W3DAnimation_'+name+'.json'));ch=anim['channels'][0]
            keys=[f & 0x7fff for f in ch['frame_and_binary_flag']];assert keys==sorted(keys)
            v=ch['values'];rules['models'][name]['animation']=dict(bone=ch['pivot'],fps=anim['fps'],frames=anim['frames'],times=keys,keys=[cv(v[i:i+3])+[v[i+3]] for i in range(0,len(v),4)])
    particles={'SovietRocketSmokeTrail'}
    audio={'specs':{},'entries':{}}
    for name in sorted(fx):
        node=lists.find(".//{*}FXList[@id='%s']"%name)
        rules['effects'][name]=tree(node)
        for decal in node.findall('.//{*}DynamicDecal'):texture(decal.get('Decal'))
        particles.update(n.get('Particle') for n in node.findall('.//{*}ParticleSystem'))
        for sound in node.findall('.//{*}Sound'):
            event=sound.get('Value');stack=[k for k in rows if k.split(':')[-1].lower()==event.lower()];seen=set();clips=[]
            while stack:
                k=stack.pop()
                if k in seen:continue
                seen.add(k)
                if k.startswith('AudioFile:'):
                    filename=k.replace(':','_')+'.wav';key=k.split(':')[1].lower();path=DEST/filename;shutil.copyfile((C if (C/'audio'/filename).exists() else land/'converted')/'audio'/filename,path);clips.append(key)
                    with wave.open(str(path)) as stream:audio['entries'][key]=dict(file='res://assets/ra3/soviet/reaper_fx/'+filename,sampleRate=stream.getframerate(),channels=stream.getnchannels(),durMs=round(stream.getnframes()*1000/stream.getframerate()))
                else:stack.extend(ids[tuple(ref)] for ref in rows[k]['references'] if tuple(ref) in ids)
            if clips:audio['specs']['RA3_REAPER_'+event]=dict(sounds=sorted(clips),volume=85,priority=9,loop=False)
    for name in sorted(particles):
        n=xml('FXParticleSystems/'+name+'.xml').find('.//{*}FXParticleSystemTemplate');rules['particles'][name]=tree(n)
        tex=n.get('ParticleTexture')
        if tex:texture(tex)
    rules['inputs']=inputs
    (DEST/'source.json').write_text(json.dumps(rules,separators=(',',':')),encoding='utf8')
    (ROOT/'iron_tide/data/ra3_reaper_sounds.json').write_text(json.dumps({'sounds':audio},indent=2),encoding='utf8')
if __name__=='__main__':main()
